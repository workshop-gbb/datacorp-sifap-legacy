---
description: "Guia de leitura para código legado Natural/Adabas — padrões da linguagem, estrutura FDT, convenções de nomes, fluxos batch"
applyTo: '**/*.nat,**/*.cpy,**/*.ddm,**/01-arqueologia/legado-sifap/**'
---

# Código Legado Natural/Adabas — Guia de Leitura

Este arquivo é ativado quando você abre programas Natural, DDMs Adabas ou qualquer arquivo dentro do diretório `01-arqueologia/legado-sifap/`. Ele ensina como ler código legado — não interpreta nenhum sistema específico por você.

## Estrutura de Programa Natural

Um programa Natural segue este esqueleto:

```
DEFINE DATA
  LOCAL
    01 #MY-VARIABLE  (A20)    /* A = alphanumeric, 20 chars */
    01 #COUNTER      (N5)     /* N = numeric, 5 digits */
    01 #AMOUNT        (P9.2)   /* P = packed decimal, 9 digits + 2 decimal */
  END-DEFINE

  /* Main logic here */

END
```

Blocos-chave a reconhecer:

| Bloco | Propósito |
|-------|---------|
| `DEFINE DATA LOCAL` | Declarações de variáveis com escopo neste programa |
| `DEFINE DATA PARAMETER` | Variáveis de entrada/saída recebidas de um chamador |
| `DEFINE DATA GLOBAL` | Compartilhado entre programas em uma sessão (raro, frágil) |
| `INPUT` | Leitura do terminal (online) ou arquivo sequencial (batch) |
| `DISPLAY` / `WRITE` | Saída para tela ou relatório |
| `MAP` | Definição de layout de tela (terminal UI) |

## CALLNAT vs PERFORM

- **`CALLNAT 'SUBPROG' parm1 parm2`** — chama um subprograma externo (arquivo-fonte separado). Parâmetros são passados por referência, salvo marcação `(AD=O)` para output-only.
- **`PERFORM subroutine-name`** — chama uma sub-rotina interna definida com `DEFINE SUBROUTINE ... END-SUBROUTINE` dentro do mesmo programa.

Ao mapear cadeias de chamada, `CALLNAT` é o importante — ele cruza fronteiras de arquivo.

## INCLUDE Copycodes

`INCLUDE copycode-name` insere um fragmento de código compartilhado em tempo de compilação, como um `#include` em C. Copycodes (arquivos `.cpy`) normalmente contêm:

- Definições de shared data area (a "struct" do Natural)
- Rotinas comuns de validação
- Blocos padrão de tratamento de erros

Quando vir `INCLUDE`, encontre o arquivo `.cpy` correspondente para entender o layout completo de dados.

## Adabas FDT (Field Definition Table)

Todo arquivo Adabas tem um FDT que define seus campos. Pense nele como o schema:

| Coluna | Significado |
|--------|---------|
| Level | Profundidade hierárquica (01 = topo, 02+ = filhos) |
| Name | Nome curto de 2 caracteres (AA, AB, AC...) |
| Format | `A` = alpha, `N` = numeric, `P` = packed, `B` = binary, `D` = date, `T` = time |
| Length | Tamanho do campo em bytes |
| Descriptor | `DE` = índice pesquisável, `MU` = multi-value (array), `PE` = periodic group (grupo repetitivo) |

### Campos MU (Multiple-Value)

Um campo marcado `MU` pode conter múltiplos valores (como um array). Em Natural, é acessado com índice: `FIELD(1)`, `FIELD(2)` etc. O máximo de ocorrências é definido no FDT.

**Mapeamento moderno**: `@ElementCollection` em JPA, ou uma coluna JSONB em PostgreSQL.

### Grupos PE (Periodic Groups)

Um grupo `PE` é um grupo repetitivo de campos relacionados — como uma linha em uma tabela embedded. Por exemplo, um histórico de endereços no qual cada ocorrência tem rua, cidade, data.

**Mapeamento moderno**: relacionamento `@OneToMany` com uma entidade embedded, ou um array JSONB.

### Super-Descriptors

Um super-descriptor combina múltiplos campos em uma única chave pesquisável (índice composto). Notação como `SU = AA + AB(1-4)` significa "concatenar o campo AA com os primeiros 4 bytes de AB".

**Mapeamento moderno**: `@Index(columnList = "col_a, col_b")` em JPA.

## Convenções de Nomes dos Anos 1990

Codebases legadas Natural usam nomes baseados em prefixos. Padrões comuns incluem:

| Padrão de Prefixo | Significado Típico |
|---|---|
| `BN-` ou `BATCH-` | Programa batch ou variável relacionada a batch |
| `PG-` ou `PROG-` | Programa principal |
| `PS-` ou `SUB-` | Subprograma (chamado via CALLNAT) |
| `AU-` ou `AUT-` | Relacionado a authorization ou audit |
| prefixo `#` em variáveis | Variável local de trabalho (convenção Natural) |
| prefixo `+` em variáveis | Variável de parâmetro passada pelo chamador |

São convenções, não regras — verifique lendo o código, não assumindo.

## Padrões de Batch Job

Programas Natural batch normalmente seguem esta estrutura:

```
READ WORK FILE 1 record
  /* process each record */
  AT END OF DATA
    /* final totals / cleanup */
  END-ENDDATA
END-WORK
```

Relatórios de control-break usam:

```
READ logical-file BY descriptor
  AT BREAK OF descriptor
    /* subtotal when descriptor value changes */
  BEFORE BREAK PROCESSING
    /* detail line for each record */
  END-BREAK
END-READ
```

## Tratamento de Packed Decimal

Packed decimal (formato `P`) armazena dígitos de forma eficiente: cada byte mantém dois dígitos, o último nibble é o sinal (C=positivo, D=negativo). Comum em cálculos financeiros.

Ao mapear para Java: sempre use `BigDecimal`, nunca `double` ou `float`. Campos packed com formato `P9.2` significam 9 dígitos totais com 2 casas decimais → `BigDecimal` com `scale(2)`.

## Estratégia de Leitura

Ao abordar um programa legado pela primeira vez:

1. **Comece com DEFINE DATA** — entenda as variáveis e seus tipos
2. **Encontre o READ ou FIND principal** — isso diz quais dados o programa processa
3. **Rastreie as chamadas CALLNAT** — estas são as dependências
4. **Procure INCLUDE copycodes** — eles expandem as definições de dados
5. **Verifique AT BREAK / AT END OF DATA** — eles revelam a lógica de relatório ou processamento
6. **Anote qualquer ESCAPE ou ON ERROR** — estes são caminhos de tratamento de erro
