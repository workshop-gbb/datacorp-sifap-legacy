# Arquivos DDM do Adabas

> **Trilha:** [Kit do Time](../../../README.md) › [Estágio 1](../../README.md) › [Legado SIFAP](../README.md) › **DDMs do Adabas**

**DDMs (Data Definition Modules, ou Módulos de Definição de Dados) do SIFAP, Sistema de Fiscalização e Administração de Pagamentos.** Eles descrevem a estrutura física e lógica do banco de dados Adabas usado pelo sistema legado. Material de referência para a Dupla 4 (DBA + QA) durante o Estágio 1.

| Campo | Valor |
|---|---|
| **Público-alvo** | A Dupla 4 (DBA + QA) lidera; todas as duplas consultam |
| **Pré-requisitos** | Ler a seção 6 (tipos de campo) de [`HOW-TO-READ-NATURAL.md`](../HOW-TO-READ-NATURAL.md) |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Mapeamento dos campos relevantes para o escopo selecionado |

---

## O que é um DDM

Um **DDM (Data Definition Module)** é o arquivo que descreve o esquema de um banco de dados Adabas, equivalente a um `CREATE TABLE` em SQL. Cada DDM lista os campos de um arquivo Adabas (FNR), com tipo, tamanho e atributos como descritor ou valor múltiplo.

**Por que isso importa:** sem ler o DDM, você não sabe quais campos existem, quais são seus tipos nem quais estruturas (`MU`, `PE`) precisarão se tornar tabelas filhas no PostgreSQL. Os nomes de campos nos programas `.NSN` são abreviações que só fazem sentido quando comparadas com o DDM.

**Como isso se aplica ao SIFAP:** o programa `CALCBENF.NSN` referencia campos como `BN-AMT-INCOME-PC` e `PS-AMT-MAX`. Para entender o que cada campo representa, consulte os membros DDM `BENEFIC` e `SOCPROG`.

---

## Conteúdo

| Arquivo | Arquivo Adabas | Descrição |
|---|---|---|
| `BENEFIC.ddm` | DBID 057 / FNR 150 | Registros de beneficiários: dados pessoais, documentos, situação cadastral, dados bancários e dependentes (PE) |
| `PAYMENT.ddm` | DBID 057 / FNR 152 | Registros de pagamentos: valores, datas, situação, banco pagador, deduções (PE) e conciliação |
| `SOCPROG.ddm` | DBID 057 / FNR 151 | Programas sociais: regras de elegibilidade, faixas de valores e parâmetros de cálculo |
| `AUDIT.ddm` | DBID 057 / FNR 153 | Trilha de auditoria: ações de usuários, alterações cadastrais e contexto do batch |
| `FDT-150-BENEFICIARY.txt` | DBID 057 / FNR 150 | **FDT física** do arquivo 150 (saída do ADAREP): leiaute real, opções `NU`/`FI`/`DE`/`UQ`, volume de dados e estimativa da janela de unload |

---

## Como ler um DDM

Os arquivos `.ddm` deste diretório são **listagens** geradas pelo utilitário `LISTDDM` do SYSDDM, ou seja, saída de máquina, não código-fonte editável. A tabela principal sempre tem as mesmas oito colunas:

```text
 T L DB Name                     F Leng  S D Remark
 - - -- ------------------------ - ----  - - ---------------------------
   1 AB NUM-CPF                  A   11    U UNFORMATTED CPF
 P 1 DA GRP-DEPEND                        (1:10) PERIODIC GROUP
 S   S2 SUPER-UF-STAT             A    3    S
        /* BG(1-2), CE(1-1)
```

| Coluna | Significado | Valores possíveis |
|---|---|---|
| **T** | Tipo de entrada | *(em branco)* = campo elementar · `G` = grupo · `M` = valor múltiplo (`MU`) · `P` = grupo periódico (`PE`) · `S` = descritor derivado |
| **L** | Nível | `1` = campo raiz · `2` = campo dentro de um grupo ou PE. Descritores derivados não têm nível |
| **DB** | *Short name* | Nome físico de **2 bytes** na FDT. É o único nome que o arquivo Adabas realmente conhece |
| **Name** | Nome longo | Existe apenas no DDM. É o nome usado pelos programas Natural nas declarações `VIEW OF` |
| **F** | Formato | `A` = alfanumérico · `N` = numérico *unpacked* (1 byte por dígito) · `P` = decimal *packed* (2 dígitos por byte) |
| **Leng** | Tamanho | Bytes, ou `dígitos,decimais` para campos com casas decimais, **sempre com vírgula** (`9,2`, nunca `9.2`) |
| **S** | *Storage option* | `N` = *null suppression* (um campo vazio não ocupa espaço nem é adicionado ao índice) · `F` = *fixed storage* (sem compactação, comum em indicadores de 1 byte) |
| **D** | Descritor | `D` = descritor · `U` = descritor único · `S` = superdescritor · `H` = hiperdescritor · `P` = descritor fonético |
| **Remark** | Comentário | Domínio de valores, sentinelas e data de adição do campo. As ocorrências `MU`/`PE` aparecem aqui como `(1:10)` |

As linhas que começam com `/*`, logo abaixo de um descritor derivado, listam **os campos que o compõem**. Por exemplo, `/* BG(1-2), CE(1-1)` significa "bytes 1–2 de `BG` concatenados com o byte 1 de `CE`".

> [!IMPORTANT]
> **`FIND ... WITH <field>` e `READ ... BY <field>` só são válidos se o campo tiver um valor na coluna `D`.** Pesquisar por um campo não indexado causa um erro de execução no Adabas, não um erro de compilação: o programa "funciona" até ser executado. Esta é a primeira verificação ao ler um programa `.NSN`.

### DDM × FDT

| | DDM (`.ddm`) | FDT (`FDT-150-BENEFICIARY.txt`) |
|---|---|---|
| O que é | Visão **lógica** usada pelo Natural | Leiaute **físico** do arquivo do banco de dados |
| Nomes | Nomes longos (`NUM-CPF`) | Apenas *short names* (`AB`) |
| Gerado por | `LISTDDM` (SYSDDM) | `ADAREP` / `ADACMP` |
| Inclui volume de dados? | Estimativas no rodapé | Sim: `TOP-ISN`, `MAXISN`, taxa de compressão, extents e estimativa de unload |

Uma equipe real de migração recebe **os dois**. O DDM explica o significado dos campos; a FDT mostra quanto dado existe e quanto tempo a extração levará.

### Armadilhas conhecidas neste corpus

- **Campos alfanuméricos usados como valores numéricos.** Vários campos são `A` no DDM, mas aparecem como `N` nos programas, inclusive em operações aritméticas e como índices de arrays. Um registro antigo com espaços em um campo `A` causa erro quando movido para `N`.
- **Sentinelas em vez de null.** `0` significa "sem prazo", `00000000000` funciona como CPF provisório e `99999999` como data desconhecida. Nenhum deles é `NULL`.
- **Campos órfãos.** Alguns campos existem no esquema há décadas, mas nenhum dos 15 programas os lê ou grava. Verifique antes de presumir que uma coluna contém dados.
- **Domínios documentados em `Remark` podem estar desatualizados.** O comentário descreve o domínio *quando o campo foi criado*, não necessariamente o que está armazenado hoje.

---

## Como usar estes arquivos durante o Estágio 1

- [ ] **Abra os DDMs relevantes para a feature selecionada.** Nem sempre os quatro são necessários.
- [ ] **Leia a seção "Como ler um DDM" acima** antes de comparar um DDM com um programa. A comparação não faz sentido sem as colunas `T`/`S`/`D`.
- [ ] **Identifique os campos `MU` e `PE`** (coluna `T` = `M` ou `P`). Eles se tornam tabelas filhas no PostgreSQL.
- [ ] **Verifique a coluna `D` antes de aceitar um `FIND`/`READ BY`.** Se o campo não for um descritor, o acesso é ilegal no Adabas.
- [ ] **Compare cada `VIEW OF` com o DDM correspondente.** Nome, formato e tamanho devem coincidir.
- [ ] **Registre o mapeamento** na seção de arestas Programa → DDM de [`dependency-map.md`](../../dependency-map.md).
- [ ] **Contribua com termos** para [`glossary.md`](../../glossary.md). Os nomes dos campos frequentemente revelam abreviações do domínio.

> [!WARNING]
> Estes arquivos são material de referência somente leitura. Não edite os DDMs.

---

### Continue lendo

| Anterior | Próximo |
|---|---|
| [Legado SIFAP, visão geral](../README.md)<br/><sub>Contexto do sistema e inventário completo.</sub> | [Programas Natural](../natural-programs/README.md)<br/><sub>Os 15 arquivos atribuídos que contêm lógica de negócio.</sub> |

<sub>[Voltar ao índice do kit](../../../README.md)</sub>
