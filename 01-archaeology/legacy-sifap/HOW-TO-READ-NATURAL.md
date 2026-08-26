# Como ler um programa Natural sem conhecer Natural

> **Trilha:** [Kit do Time](../../README.md) › [Estágio 1](../README.md) › [Legado SIFAP](README.md) › **Como ler Natural**

**Um tutorial de leitura orientado a regras de negócio.** Aprenda a extrair comportamentos relevantes de um arquivo `.NSN` em 45 minutos, mesmo sem conhecer a linguagem Natural.

| Campo | Valor |
|---|---|
| **Público-alvo** | PO, Tech Writer, analista de negócio, pessoa desenvolvedora iniciante ou qualquer pessoa que abra um `.NSN` durante o Estágio 1 |
| **Pré-requisitos** | VS Code instalado e acesso à pasta `legacy-sifap/natural-programs/` |
| **Tempo estimado** | 10 min para este guia + 45 min por programa |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Pelo menos uma regra catalogada com evidência `file.NSN#L<start>-L<end>` |

> [!TIP]
> Você só precisa ler cinco construções: comentários com `*` no início da linha, `IF/END-IF`, `MOVE`, `COMPUTE` e o bloco `FIND`/`END-FIND`. O restante da sintaxe é estrutura técnica que pode ser ignorada durante a leitura das regras.

---

## 1. Anatomia visual de um programa Natural

```text
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *    <- HEADER (comments)
* PROGRAM: CALCDSCT                                                   Every line with * is a comment.
* SYSTEM:  SIFAP - PAYMENT INSPECTION AND ADMINISTRATION SYSTEM       Read the program history here:
* AUTHOR:  ROBERTO MENDES JUNIOR                                      who changed it and when.
* DATE:    25/08/1999                                                 Valuable clues.
* CHANGED: 12/04/2007 - MARCIA HELENA - ADD JUDICIAL DEDUCTION
* PURPOSE: CALCULATE BENEFIT DEDUCTIONS
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

DEFINE DATA                                                          <- DATA DECLARATION
LOCAL USING LDASIFAP                                                   External areas first
LOCAL                                                                  (LDA/PDA), then local fields.
  1 PAYMENT-V VIEW OF PAYMENT                                      You can skip this—just note
    2 NUM-PAYMENT      (N15)                                         fields that come from a table
    2 AMT-GROSS          (P9.2)                                        (VIEW OF = DDM).
    2 AMT-DISC-TOTAL (P7.2)
  1 #AMT-MAX-DISC        (P9.2)
END-DEFINE
*
MOVE *DATN TO #DT-TODAY                                                <- PROGRAM BODY
*                                                                       The logic lives here.
* CHECK DEDUCTION CAP                                                   FOCUS HERE.
IF #TYPE-DISC NE 'J'
  IF #AMT-TOTAL-DISC > (#AMT-GROSS * 0.30)
    COMPUTE #AMT-TOTAL-DISC = #AMT-GROSS * 0.30
  END-IF
END-IF
*
END
```

**Três zonas:**

1. **Cabeçalho** (linhas com `*`): conta a história do programa. Anote autores e datas, pois indicam quando as regras foram adicionadas.
2. **`DEFINE DATA` … `END-DEFINE`**: declara os dados. Começa com áreas externas (`USING`) e termina com campos locais. Você pode ignorá-lo ou percorrê-lo para identificar quais campos DDM o programa usa.
3. **Corpo** (depois de `END-DEFINE`): **é onde fica a lógica de negócio**. Esse é o conteúdo que você quer extrair.

> [!NOTE]
> Nos arquivos-fonte (`.NSP`, `.NSN`, `.NSA`, `.NSL`, `.NSC`, `.NSD`), os comentários estão em português, em **maiúsculas e sem acentos**. Isso é intencional: o terminal 3270 do mainframe usa EBCDIC e não representa caracteres acentuados de forma confiável. Esta documentação Markdown em português usa pontuação, acentuação e capitalização normais.

---

## 2. Membros da biblioteca Natural

Um programa Natural quase nunca está isolado. O SIFAP, Sistema de Fiscalização e Administração de Pagamentos, tem programas e também **áreas de dados, copycodes e subprogramas**. Você identifica cada tipo pela extensão do arquivo.

| Extensão | Tipo de membro | Finalidade | Como entra no programa |
|---|---|---|---|
| `.NSP` | Programa | Ponto de entrada executável, batch ou online | executado diretamente (`EXEC PGM=NATBATCH` ou digitado no terminal) |
| `.NSN` | Subprograma | Lógica reutilizável com contrato de parâmetros | `CALLNAT '<name>'` |
| `.NSS` | Sub-rotina externa | Rotina compartilhada chamada pelo nome | `PERFORM <subroutine>` |
| `.NSA` | PDA, *Parameter Data Area* | Contrato de parâmetros entre chamador e chamado | `PARAMETER USING <pda>` no chamado; `LOCAL USING <pda>` no chamador |
| `.NSL` | LDA, *Local Data Area* | Campos e tabelas compartilhados por vários módulos | `LOCAL USING <lda>` |
| `.NSC` | Copycode | Fragmento de código inserido em tempo de compilação | `INCLUDE <copycode>` |
| `.NSM` | MAP | Leiaute de tela 3270 | `INPUT USING MAP '<map>'` |
| `.NSD` | DDM, *Data Definition Module* | Como o Natural enxerga um arquivo Adabas | `VIEW OF <ddm>` em `DEFINE DATA` |
| `.jcl` | JCL z/OS | Como o batch executa em produção: jobs, arquivos e agendamento | fora do Natural, `EXEC PGM=NATBATCH` |

> [!IMPORTANT]
> **A extensão identifica o tipo de membro, e o tipo determina como o módulo é invocado.** Confundir `.NSP` com `.NSN` é o erro mais comum entre iniciantes em Natural: um programa não pode ser destino de `CALLNAT`, e um subprograma não pode ser executado diretamente. O SIFAP tem **12 programas** (`.NSP`) e **5 subprogramas** (`.NSN`).

### 2.1. As quatro linhas que criam dependências

```natural
DEFINE DATA
PARAMETER USING PDAVALID    /* RECEIVES PARAMETERS FROM CALLER   (.NSA)
LOCAL USING LDASIFAP        /* USES THE SHARED LOCAL DATA AREA   (.NSL)
LOCAL
  1 #MSG               (A60)
END-DEFINE
*
CALLNAT 'SUBVALCP' #PV-TYPE-DOC #PV-CPF #PV-NIS
                   #PV-COD-RETURN #PV-MSG
                   #PV-IND-SPECIAL       /* CALLS ANOTHER MODULE (.NSN)
*
INCLUDE CCAUDIT             /* INSERTS A CODE BLOCK HERE         (.NSC)
END
```

| Linha | Significado | Localização do membro |
|---|---|---|
| `CALLNAT 'X'` | chama o subprograma `X` e passa parâmetros | `X.NSN` |
| `... USING Y` | usa a área de dados `Y` | `Y.NSA` (PDA) ou `Y.NSL` (LDA) |
| `INCLUDE Z` | insere o copycode `Z` neste ponto | `Z.NSC` |
| `PERFORM W` | executa uma sub-rotina | interna (`DEFINE SUBROUTINE W` no mesmo arquivo) ou externa `W.NSS` |

`PERFORM` normalmente permanece dentro do módulo. **`CALLNAT` cruza a fronteira do arquivo**, e isso é o que importa para o mapa de dependências.

> [!IMPORTANT]
> **Uma biblioteca Natural é plana.** Todos os membros ficam na mesma biblioteca (`SIFAPPRD`) e são resolvidos **pelo nome**, nunca pelo caminho. `CALLNAT`, `INCLUDE` e `USING` não recebem uma pasta. Por isso, o kit mantém tudo no único diretório `natural-programs/`. Os nomes dos membros têm limite de oito caracteres, o que explica abreviações como `CALCBENF` e `LDASIFAP`.

---

## 3. Construções que importam

### 3.1. Comentário, `*` no início da linha

Tudo que começa com `*` é texto livre. Sempre leia os comentários, pois eles frequentemente explicam o "porquê" de uma regra.

```natural
* CHECK DEDUCTION CAP
```

Significado: "O programa verifica o limite de dedução neste ponto".

> [!TIP]
> Os comentários frequentemente contêm datas e iniciais (`* 2007 MH - INC JUDICIAL`). Cada um é uma evidência de que uma regra foi adicionada em determinado momento da história e talvez ainda seja válida.

### 3.2. Decisão, `IF` … `END-IF`

Esta é a construção mais importante. **Toda regra de negócio está dentro de um `IF`.**

```natural
IF #TYPE-DISC NE 'J'
  IF #AMT-TOTAL-DISC > (#AMT-GROSS * 0.30)
    COMPUTE #AMT-TOTAL-DISC = #AMT-GROSS * 0.30
  END-IF
END-IF
```

Leia em voz alta: "Se o tipo de desconto não for 'J' (judicial) e o total de descontos exceder 30% do valor bruto, reduza o total ao limite de 30%".

**Operadores comuns:**

| Natural | Significado |
|---|---|
| `EQ` ou `=` | igual a |
| `NE` ou `<>` | diferente de |
| `GT` ou `>` | maior que |
| `LT` ou `<` | menor que |
| `GE` ou `>=` | maior ou igual a |
| `LE` ou `<=` | menor ou igual a |
| `AND` | e |
| `OR` | ou |

Regra extraída do exemplo: *"Descontos não judiciais (tipo diferente de J) estão limitados a 30% do valor bruto."*

### 3.3. Atribuição, `MOVE` e `COMPUTE`

`MOVE` copia um valor para uma variável. `COMPUTE` executa um cálculo.

```natural
MOVE *DATN TO #DT-TODAY               /* ASSIGNS TODAY'S DATE TO #DT-TODAY
MOVE 500.00 TO #BAND-CONTRIB(1)     /* ASSIGNS 500 TO THE FIRST RANGE
COMPUTE #VLR-MAX = #AMT-GROSS * 0.30 /* CALCULATES 30% OF THE GROSS AMOUNT
```

Tudo que vem depois de `/*` na mesma linha também é um comentário, a segunda forma de escrever comentários em Natural, frequentemente usada para anotar campos em `DEFINE DATA`.

> [!IMPORTANT]
> Literais numéricos (`500.00`, `0.30`, `0.075`) quase sempre representam regras: faixas, alíquotas ou percentuais. Registre cada um que encontrar.

### 3.4. Chamada de outro módulo, `CALLNAT '<subprograma>'`

`CALLNAT` invoca um subprograma, o equivalente a uma chamada de função. Os parâmetros seguem a ordem definida pela PDA e podem ocupar várias linhas.

```natural
CALLNAT 'SUBVALCP' #PV-TYPE-DOC #PV-CPF #PV-NIS
                   #PV-COD-RETURN #PV-MSG
                   #PV-IND-SPECIAL
```

Significado: "Este módulo delega a validação do CPF ao subprograma `SUBVALCP.NSN` e recebe o resultado em `#PV-COD-RETURN` e `#PV-MSG`".

Registre cada `CALLNAT`, `INCLUDE` e `USING` em [`dependency-map.md`](../dependency-map.md).

### 3.5. Acesso a dados, `FIND` … `END-FIND`

```natural
FIND BENEFICIARY-V WITH NUM-CPF = #CPF-STR
  IF NO RECORDS FOUND
    MOVE 'BENEFICIARY NOT FOUND' TO #MSG
    MOVE 2001 TO #COD-RETURNORNO
  END-NOREC
  MOVE BENEFICIARY-V.STAT-BENEFICIARY   TO #SIT
  MOVE BENEFICIARY-V.AMT-FAMILY-INCOME TO #INCOME
END-FIND
```

Leia em voz alta: "Encontre o beneficiário com este CPF; se nenhum for encontrado, registre o erro; se for encontrado, copie a situação e a renda para variáveis de trabalho".

Três pontos principais:

- **`IF NO RECORDS FOUND` … `END-NOREC` é a forma idiomática de tratar "não encontrado".** O bloco executa uma vez quando a pesquisa não retorna registros.
- **Os campos da view (`BENEFICIARY-V.xxx`) só são válidos dentro do bloco `FIND`.** Por isso, o padrão usual os copia para `#variáveis` antes de `END-FIND`.
- Módulos mais antigos usam variações com a mesma intenção: `IF *NUMBER(BENEFICIARY-V) = 0` ou um sinalizador lógico (`1 #FOUND-B (L)`) definido dentro do `FIND` e testado depois. Diferenças de estilo frequentemente indicam períodos distintos de manutenção. Observe a data do cabeçalho.

---

## 4. O que você pode ignorar com segurança

| Construção | O que é | Por que ignorar |
|---|---|---|
| `READ … BY …` / `END-READ` | Loop sobre registros Adabas | A regra está no `IF` dentro do loop |
| `WRITE` / `DISPLAY` / `PRINT` | Saída em tela ou relatório | É apresentação, não decisão |
| `FORMAT`, `WRITE TITLE`, `AT TOP OF PAGE`, `DEFINE PRINTER` | Formatação de relatório | É cosmético |
| `INPUT` | Lê de um terminal 3270 | Tornará-se um formulário web |
| `RESET INITIAL` | Inicializa uma variável | É detalhe técnico |
| `STORE` / `UPDATE` / `DELETE` | Persistência no Adabas | A regra está no `IF` anterior; `STORE` significa apenas "salvar" |
| `END TRANSACTION` / `BACKOUT TRANSACTION` | Controle de commit | É infraestrutura de banco de dados |
| `ON ERROR` / `END-ERROR` | Tratamento de erro técnico | Não é regra de negócio |
| `END-WORK` / `AT END OF DATA` | Fim do processamento | É estrutura, não regra |

> [!WARNING]
> `CALLNAT`, `INCLUDE` e `USING` **não** estão nesta lista. Eles são dependências e devem entrar no mapa.

---

## 5. Extração de uma regra em cinco passos

Use `CALCDSCT.NSP` como exemplo.

### Passo 1 — Leia o cabeçalho (1 min)

```natural
* PROGRAM: CALCDSCT
* PURPOSE: CALCULATE BENEFIT DEDUCTIONS
* CHANGED: 12/04/2007 - MARCIA HELENA - ADD JUDICIAL DEDUCTION
```

Registre em `business-rules-catalog.md`: "CALCDSCT calcula descontos. Alterado em 2007 para adicionar descontos judiciais, possível regra especial".

### Passo 2 — Percorra `DEFINE DATA` (30 s)

Observe duas coisas: as linhas `USING` e `VIEW OF` (de onde vêm os dados) e os nomes de variáveis que sugerem valores (`AMT-GROSS`, `TIPO-DSCT`).

### Passo 3 — Encontre as instruções `IF` (3–5 min)

Use Ctrl+F no VS Code e digite `IF`. Cada `IF` é uma regra candidata.

| Linha | Condição | Regra possível |
|---|---|---|
| L142 | `IF #TYPE-DISC NE 'J'` | Tratamento especial para descontos judiciais |
| L143 | `IF #AMT-TOTAL-DISC > (#AMT-GROSS * 0.30)` | Limite de 30% para descontos |

### Passo 4 — Encontre constantes numéricas (2 min)

Use Ctrl+F com `0.` para localizar `0.30`, `0.075` e valores semelhantes. Cada constante sem explicação provavelmente é uma alíquota ou um percentual de regra. Pesquise também `INIT <`: as tabelas de parâmetros carregam faixas e fatores inteiros de uma só vez.

### Passo 5 — Confirme com o modo Ask do GitHub Copilot (2 min)

Selecione um bloco de código no VS Code, abra o GitHub Copilot, selecione o modo Ask e envie:

> "Explique este código Natural em português. Concentre-se na regra de negócio. Ignore entrada e saída."

Compare a explicação do Copilot com sua interpretação. Se coincidirem, registre-a no catálogo.

### Do `.NSN` para uma entrada do catálogo

Para cada condicional, descreva apenas o comportamento confirmado pela equipe. Registre a evidência sem inventar uma intenção que não esteja explícita no código:

| ID | Regra | Programa de origem | Risco |
|---|---|---|---|
| BR-XXX | Comportamento confirmado | `file.NSN#L<start>-L<end>` | Avaliar |

Uma condição ambígua deve ser registrada como questão em aberto em [`mysteries-found.md`](../mysteries-found.md), não convertida em regra.

---

## 6. Tipos e formatos de campo (DDMs e variáveis)

> [!IMPORTANT]
> **Neste laboratório, o separador decimal em uma especificação de formato do código-fonte Natural é o ponto.** O Natural Community Edition 9.3.3 compila `(N9.2)` e `(P9.2)`. Ele rejeita formas com vírgula, como `(N9,2)` e `(P9,2)`, com `NAT0165`.
>
> As instalações do Natural podem variar conforme a configuração do caractere decimal, e instalações antigas de mainframe costumavam usar vírgula. Esta imersão segue a imagem do Natural CE 9.3.3. `DC=,` não funciona como alternativa aqui porque entra em conflito com o delimitador `ID` e gera `NAT0385`.
>
> Essa regra se aplica **apenas às declarações no código-fonte**. Nos valores literais do código, o separador continua sendo ponto: `MOVE 1.3500 TO #FACTOR-ADJUST` e `COMPUTE #VLR = #BRUTO * 0.30`. As listagens DDM ainda exibem tamanhos decimais com vírgula, por exemplo, `P  9,2`.

### 6.1. Formatos que você encontrará

| Notação | Significado | No PostgreSQL |
|---|---|---|
| `(A60)` | Alfanumérico, 60 caracteres | `VARCHAR(60)` |
| `(A11)` | Alfanumérico, 11 caracteres, como CPF e NIS são armazenados (preserva zeros à esquerda) | `CHAR(11)` |
| `(N11)` | Numérico *unpacked*, 11 dígitos, sem casas decimais | `NUMERIC(11)` |
| `(N8)` | Data no formato `AAAAMMDD`; o Natural não tem tipo de data aqui | `DATE` |
| `(N6)` | Período de referência no formato `AAAAMM` ou hora no formato `HHMMSS` | `INTEGER` (converter) |
| `(N9.2)` | Numérico *unpacked*, 9 dígitos, 2 casas decimais | `NUMERIC(9,2)` |
| `(P9.2)` | Decimal *packed*, 9 dígitos, 2 casas decimais | `NUMERIC(9,2)` |
| `(P13.2)` | Decimal *packed*, 13 dígitos, 2 casas decimais, acumulador de batch | `NUMERIC(13,2)` |
| `(N3.4)` | 3 dígitos, 4 casas decimais, comum em fator ou índice | `NUMERIC(3,4)` |
| `(L)` | Lógico (`TRUE` / `FALSE`) | `BOOLEAN` |

### 6.2. `P` (packed) × `N` (unpacked), dinheiro é sempre `P`

| | `N` — *unpacked* | `P` — *packed decimal* |
|---|---|---|
| Armazenamento | 1 dígito por byte | 2 dígitos por byte; o último *nibble* armazena o sinal |
| Custo | mais espaço | menos espaço, aritmética mais rápida |
| Uso comum no SIFAP | contadores, códigos, datas `AAAAMMDD`, índices de loop | **valores monetários e fatores de cálculo** |

No mainframe, dinheiro é *packed*. É o que diz o DDM, `CH AMT-FAMILY-INCOME P 9,2`, e o que os programas declaram. Quando encontrar `(P9.2)`, `(P7.2)` ou `(P13.2)` no código-fonte Natural, você está diante de um campo de valor.

> [!TIP]
> Durante a modernização, valores decimais `P` e `N` tornam-se `BigDecimal` em Java e `NUMERIC(p,s)` no PostgreSQL. **Nunca** use `double` ou `float`: o sistema legado calcula decimais exatos, e as diferenças aparecem nos centavos.

### 6.3. Arrays, a faixa de índices é explícita

| Notação | Significado |
|---|---|
| `(A60/1:10)` | 10 ocorrências de 60 caracteres |
| `(N3.4/1:27)` | 27 ocorrências de 3 dígitos com 4 casas decimais |
| `(P9.2/1:5)` | 5 ocorrências monetárias |
| `(N3.6/1:10,1:12)` | array bidimensional, 10 × 12 |

Os limites fazem parte da notação: escreva `1:27`, não apenas `27`. Arrays frequentemente aparecem com `INIT <...>`: **cada número dessa lista é uma regra candidata**. As dimensões contam uma história: 27 posições normalmente indexam UF, enquanto 12 indexam meses.

### 6.4. Estruturas do Adabas que não cabem em uma coluna

| No DDM | Significado | Consequência |
|---|---|---|
| Coluna `T` = `M` (`MU`) | Campo de valor múltiplo: vários valores em um registro | **Torna-se uma tabela filha** |
| Coluna `T` = `P` (`PE`) | Grupo periódico: sub-registros repetidos | **Torna-se uma tabela filha** |

> [!WARNING]
> `MU` (valor múltiplo) e `PE` (grupo periódico) são as únicas construções do Adabas que não são mapeadas diretamente para o PostgreSQL. Sempre que encontrar uma delas, marque-a no mapa de dependências. Elas se tornam tabelas separadas no Estágio 3.

---

## 7. Leitura de uma listagem DDM

Os arquivos `.ddm` são listagens do utilitário `LISTDDM`, saída de máquina, não código-fonte editável. A tabela principal sempre tem as mesmas colunas:

```text
 T L DB Name                     F Leng  S D Remark
 - - -- ------------------------ - ----  - - ---------------------------
   1 AB NUM-CPF                  A   11    U UNFORMATTED CPF
   1 CH AMT-FAMILY-INCOME       P  9,2  N   DECLARED INCOME
 P 1 DA GRP-DEPEND                        (1:10) PERIODIC GROUP
   2 DC NAME-DEPEND          A   60  N
 S   S2 SUPER-UF-STAT             A    3    S
        /* BG(1-2), CE(1-1)
```

| Coluna | Leia como |
|---|---|
| `T` | Tipo: *(em branco)* elementar · `G` grupo · `M` valor múltiplo (`MU`) · `P` grupo periódico (`PE`) · `S` descritor derivado |
| `L` | Nível: `1` campo raiz · `2` campo dentro de um grupo ou PE |
| `DB` | *Short name* de 2 bytes, o nome físico conhecido pelo Adabas |
| `Name` | Nome longo, aquele que aparece nas declarações `VIEW OF` dos programas |
| `F` | Formato: `A` alfanumérico · `N` numérico *unpacked* · `P` decimal *packed* |
| `Leng` | Tamanho em bytes; decimais usam `dígitos,decimais` (`9,2`) |
| `S` | Armazenamento: `N` *null suppression* · `F` *fixed storage* |
| `D` | Índice: `D` descritor · `U` único · `S` super · `H` hiper · `P` fonético · *(em branco)* não indexado |

A linha que começa com `/*`, logo abaixo de um descritor derivado, lista **os campos que o compõem**. No exemplo, `SUPER-UF-STAT` concatena os dois primeiros bytes de `BG` (UF) com o primeiro byte de `CE` (situação), o equivalente a um índice composto.

### 7.1. `FIND ... WITH` só é permitido em um descritor

`FIND` pesquisa por um índice do Adabas. Portanto, `FIND <view> WITH <field>` **só funciona se o campo tiver um valor na coluna `D`** (`D`, `U`, `S`, `H` ou `P`). Um campo sem índice não pode ser pesquisado.

| Campo em `BENEFIC.ddm` | Coluna `D` | `FIND ... WITH` é permitido? |
|---|---|---|
| `AB NUM-CPF` | `U` | sim |
| `CE STAT-BENEFICIARY` | `D` | sim |
| `CH AMT-FAMILY-INCOME` | *(em branco)* | **não** |
| `AD MOTHER-NAME` | *(em branco)* | **não** |

Sem um descritor, o programa precisa de outro caminho, normalmente `READ <view> BY <descriptor>` com um `IF` que filtra dentro do loop.

**Como verificar em 15 segundos:** abra o `.ddm`, use Ctrl+F com o nome do campo e examine a coluna imediatamente anterior a `Remark`.

A legenda completa das colunas está no rodapé de cada `.ddm` e no [README dos DDMs](adabas-ddms/README.md).

---

## 8. Atalhos do VS Code para economizar tempo

<details>
<summary><strong>Tabela de atalhos e dicas de uso do modo Ask do GitHub Copilot</strong></summary>

| Atalho | O que faz |
|---|---|
| Ctrl+F | Pesquisa dentro do arquivo |
| Ctrl+Shift+F | Pesquisa em todos os arquivos |
| Ctrl+G + número | Vai para a linha N |
| Selecionar + modo Ask do GitHub Copilot | Envia um trecho diretamente para análise |

> [!TIP]
> Selecione o programa Natural inteiro, abra o painel do GitHub Copilot, selecione o modo Ask e envie: "Liste todas as regras de negócio deste programa Natural. Para cada uma, informe o intervalo de linhas, a condição em português e o nível de risco (CRÍTICO/ALTO/MÉDIO/BAIXO)". Em 30 segundos, 80% do trabalho está feito. Sempre confirme examinando o `IF` original.

</details>

---

## 9. Mapa dos 15 programas, guia de leitura

| Categoria | Programas | O que esperar |
|---|---|---|
| Cadastro | `CADBENEF`, `CADDEPEN`, `CADPROG` | Telas de entrada. Validações de CPF, nome e data. |
| Cálculo | `CALCBENF`, `CALCCORR`, `CALCDSCT` | Fórmulas e constantes. A maioria das regras financeiras está aqui. |
| Validação | `VALBENEF`, `VALDOCS`, `VALELEG` | Sequências de instruções `IF`. Cada uma se torna um teste. |
| Batch | `BATCHPGT`, `BATCHREL`, `BATCHCON` | Muitas instruções `CALLNAT`. Revelam o fluxo de negócio. |
| Consulta e relatórios | `CONSBENF`, `RELPGT`, `RELAUDIT` | Muitas instruções `READ`/`WRITE`. Poucas regras, leitura rápida. |

> [!NOTE]
> A pasta `natural-programs/` também contém **membros de apoio** (PDA, LDA, copycode, subprograma e JCL). Eles são infraestrutura compartilhada: consulte-os quando um dos seus três programas usar `USING`, `INCLUDE` ou `CALLNAT`, mas eles **não são leitura atribuída**. O inventário completo está no [README dos programas Natural](natural-programs/README.md).

---

## 10. Erros comuns de leitura

| Erro | Correção |
|---|---|
| Tentar entender todas as linhas | Concentre-se apenas em `IF`, `COMPUTE` com constantes e comentários. |
| Ler na ordem do arquivo | Vá diretamente às instruções `IF` usando Ctrl+F. |
| Confundir uma variável (`#VLR`) com um campo DDM (`AMT-GROSS`) | `#` no início = variável local. Sem `#` = campo do banco de dados. |
| Presumir que todo `MOVE` é uma regra | `MOVE` é atribuição. A regra é o `IF` que selecionou o `MOVE`. |
| Copiar a forma com vírgula de uma listagem DDM (`P 9,2`) para a documentação do código-fonte Natural | As declarações no código-fonte usam ponto neste laboratório: `(N9.2)`, `(P13.2)`. |
| Tratar `(P9.2)` como algo diferente de dinheiro | `P` é *packed decimal*, o formato monetário do mainframe. |
| Registrar a leitura de um campo da view fora do bloco `FIND` | Verifique se o valor foi copiado para uma `#variável` antes de `END-FIND`. |
| Registrar uma regra sem citar as linhas | Sempre registre `file.NSN#L<start>-L<end>`. A CI rejeita entradas sem essa referência. |

---

## 11. Quando pedir ajuda

Se você não conseguir extrair pelo menos uma regra de um programa em 45 minutos:

1. Avise a pessoa facilitadora.
2. Mostre o programa que está lendo.
3. Pergunte: "Qual `IF` aqui é uma regra de negócio e qual é apenas técnico?".

---

### Continue lendo

| Anterior | Próximo |
|---|---|
| [Legado SIFAP, visão geral](README.md)<br/><sub>Contexto do sistema e inventário completo.</sub> | [GUIDE do Estágio 1](../GUIDE.md)<br/><sub>Roteiro cronometrado de 90 minutos.</sub> |

<sub>[Voltar ao índice do kit](../../README.md)</sub>
