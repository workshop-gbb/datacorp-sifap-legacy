# Provisionamento Adabas/Natural do SIFAP

Estes scripts são montados na VM em `/opt/sifap/provisioning`. O ponto de entrada do cloud-init é:

```bash
sudo /opt/sifap/provisioning/run-all.sh
```

Os scripts registram logs em stdout e em `/var/log/sifap-provisioning.log`.

## Fases

`SIFAP_PHASE` controla o `run-all.sh`:

- `auto` (padrão) — executa a fase base e verifica se todos os DDMs obrigatórios já existem. Se existirem, continua por finalize. Caso contrário, imprime uma mensagem de espera pelos DDMs e encerra com **0**. Uma implantação nova ainda não tem DDMs do Natural, portanto esse estado não pode parecer uma falha de provisionamento.
- `base` — carrega o Adabas, verifica os quatro arquivos e cataloga somente as três áreas de dados. Não executa smoke tests nem exige DDMs.
- `finalize` — exige os quatro DDMs, cataloga subprogramas e programas, executa smoke tests e grava `/opt/sifap/PROVISIONED` somente depois que tudo isso termina com sucesso.

Depois de criar os DDMs manualmente, execute:

```bash
sudo SIFAP_PHASE=finalize /opt/sifap/provisioning/run-all.sh
```

Reiniciar o serviço systemd também funciona quando ele invoca `run-all.sh` sem sobrescrever `SIFAP_PHASE`, pois `auto` detecta os DDMs e continua em finalize.

## Scripts

- `run-all.sh` — orquestra as fases `auto`, `base` e `finalize`.
- `01-load-adabas.sh` — cria os arquivos Adabas 150–153 e carrega `seed/{beneficiary,payment,social-program,audit}.dat` com `seed/layout-*.txt`.
- `02-build-natural.sh` — copia as fontes do SIFAP para a biblioteca `SIFAPPRD`, registra-as com `ftouch`, cataloga as áreas de dados em base e cataloga os subprogramas/programas dependentes de DDM em finalize.
- `03-smoke-test.sh` — executa `CONSBENF` para um CPF da seed e `BATCHPGT` para o período `202601` (sobrescreva com `SIFAP_SMOKE_PERIOD`).
- `lib.sh` — oferece logs, auxiliares de contêiner, `ftouch`, execução do Natural em pty/`expect`, detecção de DDM e verificação do catálogo.

## Criação manual dos DDMs

A carga do Adabas é automatizada, mas a criação dos DDMs é uma etapa manual executada uma única vez no NaturalONE. Esta é uma limitação do Natural Community Edition verificada em `softwareag/natural-ce:9.3.3`:

- `natural BATCHMODE ...` falha com Startup Error 42; o modo batch não está disponível na Community Edition.
- O Natural CE não fornece objetos utilizáveis do utilitário `SYSDDM`.
- `ftouch lib=SYSDDM ...` falha com o código de retorno 6149.
- Catalogar uma listagem de DDM como fonte falha com `NAT4225 Invalid level`; uma listagem de DDM não é código-fonte Natural compilável.

Use o NaturalONE com o Natural Development Server exposto pelo lab na porta `2700`. Gere os DDMs a partir do banco de dados Adabas ativo (`DBID 12`) e destes arquivos:

| FNR | Nome do membro DDM |
| --- | --- |
| 150 | `BENEFIC` |
| 151 | `SOCPROG` |
| 152 | `PAYMENT` |
| 153 | `AUDIT` |

Os nomes curtos são obrigatórios por causa do limite de oito caracteres do Natural para nomes de membros. Os DDMs gerados devem estar no diretório GP da biblioteca que os utiliza como `BENEFIC.NGD`, `SOCPROG.NGD`, `PAYMENT.NGD` e `AUDIT.NGD`.

## Marcadores

- `/opt/sifap/state/DDMS-READY` — gravado quando o provisionamento detecta os quatro arquivos `.NGD` em `SIFAPPRD/GP`. Indica que a etapa manual dos DDMs foi concluída.
- `/opt/sifap/PROVISIONED` — gravado somente depois que finalize termina com sucesso, incluindo a detecção dos DDMs, a catalogação dos subprogramas/programas no Natural e os smoke tests.

## Mecanismo de build do Natural

O Natural CE não pode usar `BATCHMODE` (`Natural Startup Error: 42`). O Natural também não examina `SRC`; cada membro fonte deve ser registrado individualmente com `ftouch lib=<LIB> sm -s <file>` para que `FILEDIR.SAG` possa encontrá-lo. Por isso, a compilação e a execução dos smoke tests usam `natural SM=ON "STACK=(...)"` em uma pty interativa controlada por `expect`. `SM=ON` deve corresponder ao registro em modo estruturado ou o Natural informa erros de modo.

## Inventário de compilação

1. DDMs manuais em `SIFAPPRD/GP`: `BENEFIC`, `SOCPROG`, `PAYMENT`, `AUDIT`.
2. Áreas de dados: `PDAVALID`, `PDACALC`, `LDASIFAP`.
3. Copycodes somente como fonte: `CCVALCPF`, `CCAUDIT`.
4. Subprogramas: `SUBVALCP`, `SUBVALNI`, `VALBENEF`, `VALELEG`, `CALCBENF`.
5. Programas: `CADBENEF`, `CONSBENF`, `BATCHPGT`, `BATCHREL`, `RELPGT`, `CADPROG`, `CADDEPEN`, `VALDOCS`, `CALCCORR`, `CALCDSCT`, `RELAUDIT`, `BATCHCON`.

## Comportamento de reexecução

É seguro executar `run-all.sh` novamente. O carregador do Adabas grava marcadores no volume de dados do Adabas e ignora os arquivos já carregados. Ele recusa intencionalmente recargas destrutivas com `--force`; exclua e recrie manualmente o banco de dados do lab quando precisar recarregá-lo.

## Asserções dos smoke tests

`03-smoke-test.sh` verifica que:

- A saída de `CONSBENF` contém `SIFAP - BENEFICIARY INFORMATION` ou `BENEFICIARY QUERY`, contém o sufixo do CPF da seed e **não** contém `not found`, `não encontrado` nem `nao encontrado`.
- A saída de `BATCHPGT` contém `BATCHPGT - MONTHLY PAYMENT GENERATION`, contém o período do smoke test e contém uma frase de resumo de negócio: `PAYMENTS GENERATED`, `NO PAYMENT GENERATED` ou `TOTAL PROCESSED`.

## Fatos resolvidos e questões ainda abertas

Resolvido:

- Não é possível gerar DDMs copiando arquivos `.NSD` para `SYSDDM/SRC` no Natural CE.
- O provisionamento com `STOW`/modo batch não está disponível no Natural CE; o lab usa `ftouch` com `STACK`/`CATALOG` controlado por pty.
- Os nomes dos membros DDM compatíveis com o limite de oito caracteres são `BENEFIC`, `SOCPROG`, `PAYMENT` e `AUDIT`.

Ainda em aberto até uma execução completa da VM depois da criação manual dos DDMs:

- Se todos os cinco subprogramas e 12 programas são catalogados sem erros depois da aplicação das correções nas fontes.
- Se os dois caminhos de smoke test passam com os DDMs finais gerados manualmente e os dados carregados.
