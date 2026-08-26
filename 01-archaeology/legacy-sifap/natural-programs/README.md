# Programas Natural

> **Trilha:** [Kit do Time](../../../README.md) › [Estágio 1](../../README.md) › [Legado SIFAP](../README.md) › **Programas Natural**

**Os 15 membros Natural atribuídos do SIFAP, Sistema de Fiscalização e Administração de Pagamentos, mais os nove membros de apoio da biblioteca.** Os programas implementam a lógica de negócio do sistema legado. Cada dupla lê três programas durante o Estágio 1.

| Campo | Valor |
|---|---|
| **Público-alvo** | Todas as duplas, cada uma lê os três programas que recebeu |
| **Pré-requisitos** | Ler [`HOW-TO-READ-NATURAL.md`](../HOW-TO-READ-NATURAL.md) |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Regras catalogadas com evidência `file.NSN#L<start>-L<end>` e mapa de dependências iniciado |

> [!NOTE]
> Estes arquivos são material de referência somente leitura. Durante o Estágio 1, as duplas analisam os programas para extrair regras de negócio e mapeá-las para o sistema moderno (Java 21 + Spring Boot).

---

## O que há nesta pasta

| Grupo | Quantidade | Extensões | O que fazer com eles |
|---|---|---|---|
| **Membros atribuídos** | 15 | `.NSP` (12 programas), `.NSN` (3 subprogramas) | **Leitura atribuída.** Três por dupla |
| **Membros de apoio** | 9 | `.NSA`, `.NSL`, `.NSC`, `.NSN`, `.jcl` | **Consulte quando necessário.** Infraestrutura compartilhada |

> [!IMPORTANT]
> **Sua carga de leitura não mudou: continuam sendo três programas por dupla.**
> Os nove membros de apoio são a infraestrutura da biblioteca: áreas de dados, copycodes, dois subprogramas de validação e dois JCLs. Abra um deles quando um dos *seus* programas usar `USING`, `INCLUDE` ou `CALLNAT` e você precisar entender o significado daquele nome. Eles **não** são programas extras, **não** pertencem a nenhuma dupla e **não** contam entre as três leituras atribuídas.

Tudo fica em um único diretório porque uma biblioteca Natural é **plana**: `CALLNAT`, `INCLUDE` e `USING` resolvem membros **pelo nome**, nunca pelo caminho. Consulte a [seção 2 de `HOW-TO-READ-NATURAL.md`](../HOW-TO-READ-NATURAL.md#2-membros-da-biblioteca-natural).

---

## 1. Os 15 programas atribuídos, distribuídos por dupla

| Dupla | Programa | Autor | Ano | Descrição |
|---|---|---|---|---|
| **1 · Visão** (PO + RE), cadastro | `CADBENEF.NSP` | Roberto Meirelles | 1997 | Cadastro de beneficiário: inclusão, alteração e exclusão |
| | `CADDEPEN.NSP` | José A. Lima | 1998 | Cadastro de dependente vinculado ao beneficiário titular |
| | `CADPROG.NSP` | Fernanda C. Oliveira | 1997 | Cadastro de programa social: parâmetros e faixas de valores |
| **2 · Arquitetura** (EA + SA), batch | `BATCHPGT.NSP` | José A. Lima | 1999 | Pagamento em batch: gera ciclos mensais de pagamento |
| | `BATCHREL.NSP` | José A. Lima | 1999 | Relatório em batch: produz relatórios gerenciais |
| | `BATCHCON.NSP` | Patrícia H. Moura | 2002 | Conciliação em batch: concilia pagamentos com o SIAFI |
| **3 · Implementação** (TL + Dev), cálculo | `CALCBENF.NSN` | Roberto Meirelles | 1998 | Calcula o valor do benefício por programa e faixa |
| | `CALCCORR.NSP` | Patricia Gomes de Souza | 2001 | Calcula correções retroativas de pagamentos usando índices IPCA |
| | `CALCDSCT.NSP` | Roberto Mendes Junior | 1999 | Calcula deduções obrigatórias e limites de desconto |
| **4 · Qualidade** (DBA + QA), validação | `VALBENEF.NSN` | Roberto Meirelles | 1997 | Valida dados cadastrais (CPF, NIS) |
| | `VALDOCS.NSP` | Ana Lucia Pereira | 1998 | Valida CPF, NIS/PIS, RG, CTPS e documentos comprobatórios |
| | `VALELEG.NSN` | Fernanda C. Oliveira | 1999 | Valida a elegibilidade segundo as regras do programa |
| **5 · Operações** (DevOps + TW), consulta e relatórios | `CONSBENF.NSP` | Marcia Helena Oliveira | 1998 | Consulta dados do beneficiário por CPF ou NIS (tela 3270) |
| | `RELPGT.NSP` | Ana Lucia Pereira | 1999 | Relatório detalhado de pagamentos por período e programa |
| | `RELAUDIT.NSP` | Roberto Mendes Junior | 2002 | Relatório da trilha de auditoria com filtros por período e ação |

---

## 2. Os nove membros de apoio, infraestrutura compartilhada

Nenhum desses membros pertence a uma dupla ou conta como leitura atribuída.

| Membro | Tipo | Como aparece no código | Finalidade |
|---|---|---|---|
| `PDAVALID.NSA` | PDA | `PARAMETER USING PDAVALID` / `LOCAL USING PDAVALID` | Contrato de parâmetros da família de validação de documentos: CPF e NIS são entradas; código de retorno e mensagem são saídas |
| `PDACALC.NSA` | PDA | `PARAMETER USING PDACALC` / `LOCAL USING PDACALC` | Contrato de parâmetros da cadeia de pagamentos: chave e contexto do beneficiário são entradas; valores calculados são saídas |
| `LDASIFAP.NSL` | LDA | `LOCAL USING LDASIFAP` | Tabelas compartilhadas de parâmetros: fator regional, faixas de renda, alíquotas, UF, datas e janela de século (Y2K) |
| `CCVALCPF.NSC` | Copycode | `INCLUDE CCVALCPF` + `PERFORM VALID-CPF-STANDARD` | Rotina módulo 11 de CPF inserida em tempo de compilação, o caminho **antigo** de validação |
| `CCAUDIT.NSC` | Copycode | `INCLUDE CCAUDIT` + `PERFORM GRAVA-AUDIT` | Bloco padrão para gravar a trilha de auditoria no arquivo 153 |
| `SUBVALCP.NSN` | Subprograma | `CALLNAT 'SUBVALCP' ...` | Validação de CPF (módulo 11) que pode ser chamada, o caminho **novo** de validação |
| `SUBVALNI.NSN` | Subprograma | `CALLNAT 'SUBVALNI' ...` | Validação de NIS/PIS/PASEP (módulo 11) que pode ser chamada |
| `SIFAPJ01.jcl` | JCL z/OS | fora do Natural | Job da **folha mensal**, executa `BATCHPGT` por meio de `NATBATCH` |
| `SIFAPJ02.jcl` | JCL z/OS | fora do Natural | Job de **relatórios mensais**, executa `BATCHREL` e `RELPGT` |

> [!NOTE]
> `SUBVALCP.NSN` e `SUBVALNI.NSN` têm a extensão `.NSN`, assim como outros membros atribuídos, mas são **subprogramas**: existem apenas para serem chamados por `CALLNAT` e não executam `INPUT` nem `WRITE`. Eles não estão entre os 15 membros atribuídos.

---

## 3. Do JCL ao programa, o fluxo batch de produção

Os dois JCLs tornam o fluxo mensal rastreável de ponta a ponta:

| Job | Quando executa | O que executa | Saída |
|---|---|---|---|
| `SIFAPJ01.jcl` | Mensalmente, no primeiro dia útil | `BATCHPGT` | Folha mensal e arquivo de remessa bancária |
| `SIFAPJ02.jcl` | Mensalmente, no segundo dia útil, depois de `SIFAPJ01` | `BATCHREL` e `RELPGT` | Relatório consolidado e relatório analítico por programa |

Cada JCL documenta em comentários o agendamento (Control-M), os arquivos alocados e o procedimento de reinício. Essa é a melhor fonte para responder "o que acontece todo mês e em qual ordem?".

---

## 4. Mapa de dependências, como construí-lo

Os membros desta pasta referenciam uns aos outros. Descobrir **quem chama quem** é o exercício de mapeamento de dependências do Estágio 1: o resultado deve ser registrado em [`dependency-map.md`](../../dependency-map.md), não publicado aqui.

**Os quatro tipos de aresta e como encontrá-los:**

```bash
cd 01-archaeology/legacy-sifap/natural-programs

grep -n "CALLNAT" *.NSP *.NSN   # chamada de subprograma   (aresta entre módulos)
grep -n "INCLUDE" *.NSP *.NSN   # copycode inserido        (aresta para .NSC)
grep -n "USING"   *.NSP *.NSN   # PDA e LDA em uso         (aresta para .NSA/.NSL)
grep -n -A 8 "CMSYNIN" *.jcl     # programa executado por cada job
```

No VS Code, o equivalente é Ctrl+Shift+F com a expressão regular `CALLNAT|INCLUDE|USING` e o filtro de arquivos `*.NSP,*.NSN`.

**O que registrar para cada aresta encontrada:**

| Campo | Exemplo |
|---|---|
| Origem | `BATCHPGT` |
| Tipo | `CALLNAT` · `INCLUDE` · `USING` · `JCL executa` |
| Destino | nome do membro chamado |
| Evidência | `file.NSN#L<line>` |

> [!TIP]
> Três orientações para economizar tempo:
>
> 1. **Confirme cada aresta no código.** Um comentário no cabeçalho é uma pista, não uma prova: ele pode mencionar uma dependência ausente no corpo do programa ou omitir uma que está presente.
> 2. **Algumas arestas cruzam duplas.** Se um dos seus programas chamar outro atribuído a outra dupla, coordene a leitura com ela antes de finalizar o mapa. É assim que o desenho do sistema surge.
> 3. **Comece pelos membros de apoio.** Pesquisar `SUBVALCP`, `SUBVALNI`, `CCVALCPF`, `CCAUDIT`, `PDAVALID`, `PDACALC` e `LDASIFAP` em todo o diretório revela o esqueleto do grafo em minutos.

---

### Continue lendo

| Anterior | Próximo |
|---|---|
| [Legado SIFAP, visão geral](../README.md)<br/><sub>Contexto e história do sistema.</sub> | [DDMs do Adabas](../adabas-ddms/README.md)<br/><sub>Estruturas de dados do Adabas.</sub> |

<sub>[Voltar ao índice do kit](../../../README.md)</sub>
