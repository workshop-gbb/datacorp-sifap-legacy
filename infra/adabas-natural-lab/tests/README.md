# Testes do carregador do lab Adabas/Natural

Estes testes protegem o caminho de carga do Adabas CE comprovado empiricamente para o SIFAP.

## Nível 1: rápido/offline

```bash
python3 -m pytest infra/adabas-natural-lab/tests -m "not live"
```

Abrange o parsing de DDM, a emissão de FDT, as contagens de descritores, a sintaxe de descritores derivados, o mapeamento FDT `N`→`U`, a aritmética da largura de campos compactados, o layout da seed de largura fixa, o enquadramento E4, as contagens de ocorrências MU/PE de um byte e a codificação de grupos periódicos orientada por ocorrência. Também fixa o contrato do carregador: `adafdu` recebe a FDT por `FDUFDT`, `adacmp` recebe somente parâmetros e lê os dados de `CMPIN`, e o caminho padrão de carga é `adamup db=<DBID> update=<FNR>,add`.

## Nível 2: ao vivo e condicionado ao Docker

```bash
python3 -m pytest infra/adabas-natural-lab/tests -m live
```

Requer Docker e `softwareag/adabas-ce:7.4.0`. O teste inicia `sifap-ada-tests` com `--platform linux/amd64 -e ACCEPT_EULA=Y`, executa o carregador real, verifica os registros adicionados aos arquivos 150-153 (`500`, `6`, `2000`, `200`) e verifica que o ADACMP não encontrou registros incorretos. Se o Docker ou a imagem não estiver disponível, o teste é ignorado com uma mensagem clara.

## Por que isso existe

Uma carga pode parecer bem-sucedida enquanto danifica silenciosamente o acesso por chave ou desloca campos compactados. Estes testes detectam regressões como a perda posicional das colunas opcionais `S`/`D` do DDM, o uso do arquivo obsoleto `FDT-150-BENEFICIARY.txt`, contagens MU/PE de dois bytes, codificação PE orientada por campo, palavras-chave inválidas do ADACMP ou o retorno acidental a um fluxo indisponível centrado em `adalod`.
