<!-- markdownlint-disable MD013 MD033 MD041 -->

# Como Ler um Programa Natural Sem Saber Natural

> **Trilha:** [Kit do Time](../../README.md) › [Estágio 1](../README.md) › [Legado SIFAP](README.md) › **Como ler Natural**

**Tutorial de leitura orientada a regras de negócio.** Você aprende a extrair os comportamentos relevantes de um arquivo `.NSN` em 45 minutos, mesmo sem conhecer a linguagem Natural.

| Campo | Valor |
|---|---|
| **Público-alvo** | PO, Tech Writer, analista de negócio, desenvolvedor júnior — qualquer pessoa que vai abrir um `.NSN` no Estágio 1 |
| **Pré-requisitos** | VS Code instalado; acesso à pasta `legado-sifap/natural-programs/` |
| **Tempo estimado** | 10 min para este guia + 45 min por programa |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Pelo menos uma regra catalogada com evidência `arquivo.NSN#L<início>-L<fim>` |

> [!TIP]
> Você só precisa ler cinco construções: os comentários com `*` no início da linha, `IF/END-IF`, `MOVE`, `COMPUTE` e o bloco `FIND`/`END-FIND`. O restante da sintaxe é estrutura técnica que pode ser ignorada na leitura de regras.

---

## 1. Anatomia visual de um programa Natural

```text
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *    <- CABECALHO (comentarios)
* PROGRAMA: CALCDSCT                                                  Toda linha com * e comentario.
* SISTEMA:  SIFAP - SIST. FISC. ADM. PAGAMENTOS                      Leia aqui o historico do
* AUTOR:    ROBERTO MENDES JUNIOR                                     programa: quem mexeu e
* DATA:     25/08/1999                                                quando. Pistas valiosas.
* ALTERADO: 12/04/2007 - MARCIA HELENA - INC DESC JUDICIAL
* OBJETIVO: CALCULO DESCONTOS E DEDUCOES DO BENEFICIO
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

DEFINE DATA                                                          <- DECLARACAO DE DADOS
LOCAL USING LDASIFAP                                                   Primeiro as areas externas
LOCAL                                                                  (LDA/PDA), depois os campos
  1 PAGAMENTO-V VIEW OF PAGAMENTO                                      proprios. Pode pular — so
    2 NUM-PAGAMENTO      (N15)                                         anote os campos que vem de
    2 VLR-BRUTO          (P9,2)                                        tabela (VIEW OF = DDM).
    2 VLR-DESCONTO-TOTAL (P7,2)
  1 #VLR-MAX-DSCT        (P9,2)
END-DEFINE
*
MOVE *DATN TO #DT-HOJE                                                <- CORPO DO PROGRAMA
*                                                                       Aqui mora a logica.
* CHECK DEDUCTION CAP                                                   FOQUE AQUI.
IF #TIPO-DSCT NE 'J'
  IF #VLR-TOTAL-DSCT > (#VLR-BRUTO * 0.30)
    COMPUTE #VLR-TOTAL-DSCT = #VLR-BRUTO * 0.30
  END-IF
END-IF
*
END
```

**Três zonas:**

1. **Cabeçalho** (linhas com `*`): conta a história do programa. Anote autores e datas — eles indicam quando regras foram adicionadas.
2. **`DEFINE DATA` … `END-DEFINE`**: declara os dados. Começa pelas áreas externas (`USING`) e termina nos campos próprios. Pode pular, ou olhar para identificar quais campos do DDM o programa usa.
3. **Corpo** (depois de `END-DEFINE`): **aqui está a lógica de negócio**. É o que você quer extrair.

> [!NOTE]
> Nos fontes (`.NSN`, `.NSA`, `.NSL`, `.NSC`, `.ddm`) os comentários estão em português **maiúsculo e sem acentos**. Não é descuido: o terminal 3270 do mainframe usa EBCDIC e não representa acentuação de forma confiável. Nesta documentação em Markdown, acentos são normais.

---

## 2. Os membros de uma biblioteca Natural

Um programa Natural quase nunca está sozinho. O SIFAP tem programas, mas também **áreas de dados, copycodes e subprogramas**. Você reconhece cada tipo pela extensão do arquivo.

| Extensão | Tipo de membro | Para que serve | Como entra no programa |
|---|---|---|---|
| `.NSN` | Programa ou subprograma | Lógica executável | executado direto, ou chamado por `CALLNAT '<nome>'` |
| `.NSA` | PDA — *Parameter Data Area* | Contrato de parâmetros entre chamador e chamado | `PARAMETER USING <pda>` no chamado; `LOCAL USING <pda>` no chamador |
| `.NSL` | LDA — *Local Data Area* | Campos e tabelas compartilhados por vários módulos | `LOCAL USING <lda>` |
| `.NSC` | Copycode | Trecho de código colado em tempo de compilação | `INCLUDE <copycode>` |
| `.NSM` | MAP | Layout de tela 3270 | `INPUT USING MAP '<map>'` |
| `.NSS` | Subrotina externa | Rotina compartilhada, chamada pelo nome | `PERFORM <subrotina>` |
| `.jcl` | JCL z/OS | Como o batch roda em produção: jobs, arquivos, agendamento | fora do Natural — `EXEC PGM=NATBATCH` |

### 2.1. As quatro linhas que criam dependência

```natural
DEFINE DATA
PARAMETER USING PDAVALID    /* RECEBE PARAMETROS DE QUEM CHAMOU  (.NSA)
LOCAL USING LDASIFAP        /* USA A AREA LOCAL COMPARTILHADA    (.NSL)
LOCAL
  1 #MSG               (A60)
END-DEFINE
*
CALLNAT 'SUBVALCP' #PV-TIPO-DOC #PV-CPF #PV-NIS
                   #PV-COD-RETORNO #PV-MSG
                   #PV-IND-ESPECIAL       /* CHAMA OUTRO MODULO  (.NSN)
*
INCLUDE CCAUDIT             /* COLA UM BLOCO DE CODIGO AQUI      (.NSC)
END
```

| Linha | Significa | Onde está o membro |
|---|---|---|
| `CALLNAT 'X'` | chama o subprograma `X` e passa parâmetros | `X.NSN` |
| `... USING Y` | usa a área de dados `Y` | `Y.NSA` (PDA) ou `Y.NSL` (LDA) |
| `INCLUDE Z` | cola o copycode `Z` neste ponto | `Z.NSC` |
| `PERFORM W` | executa uma sub-rotina | interna (`DEFINE SUBROUTINE W` no próprio arquivo) ou externa `W.NSS` |

`PERFORM` normalmente fica dentro do módulo. **`CALLNAT` cruza a fronteira do arquivo** — é ele que interessa ao mapa de dependências.

> [!IMPORTANT]
> **A biblioteca Natural é plana.** Todos os membros vivem na mesma biblioteca (`SIFAPPRD`) e são resolvidos **pelo nome**, nunca por caminho. `CALLNAT`, `INCLUDE` e `USING` não recebem pasta — por isso o kit mantém tudo em `natural-programs/`, num diretório só. Nome de membro tem no máximo 8 caracteres: é daí que vêm as abreviações como `CALCBENF` e `LDASIFAP`.

---

## 3. As construções que importam

### 3.1. Comentário — `*` no início da linha

Tudo que começa com `*` é texto livre. Leia sempre os comentários — frequentemente eles explicam o "porquê" da regra.

```natural
* CHECK DEDUCTION CAP
```

Tradução: "Aqui o programa verifica o teto do desconto."

> [!TIP]
> Comentários frequentemente têm datas e iniciais (`* 2007 MH - INC JUDICIAL`). Cada uma é evidência de que uma regra foi adicionada em um momento histórico — e ainda pode estar válida.

### 3.2. Decisão — `IF` … `END-IF`

Esta é a construção mais importante. **Toda regra de negócio está dentro de um `IF`.**

```natural
IF #TIPO-DSCT NE 'J'
  IF #VLR-TOTAL-DSCT > (#VLR-BRUTO * 0.30)
    COMPUTE #VLR-TOTAL-DSCT = #VLR-BRUTO * 0.30
  END-IF
END-IF
```

Leitura em voz alta: "Se o tipo de desconto não é 'J' (judicial), e se o valor total dos descontos é maior que 30% do valor bruto, então reduza o total ao limite de 30%."

**Operadores comuns:**

| Natural | Significado |
|---|---|
| `EQ` ou `=` | igual |
| `NE` ou `<>` | diferente |
| `GT` ou `>` | maior |
| `LT` ou `<` | menor |
| `GE` ou `>=` | maior ou igual |
| `LE` ou `<=` | menor ou igual |
| `AND` | e |
| `OR` | ou |

Regra extraída do exemplo: *"Descontos não judiciais (tipo diferente de J) têm teto de 30% do valor bruto."*

### 3.3. Atribuição — `MOVE` e `COMPUTE`

`MOVE` copia um valor para uma variável. `COMPUTE` faz uma conta.

```natural
MOVE *DATN TO #DT-HOJE               /* ATRIBUI A DATA DE HOJE A #DT-HOJE
MOVE 500.00 TO #FAIXA-CONTRIB(1)     /* ATRIBUI 500 A PRIMEIRA FAIXA
COMPUTE #VLR-MAX = #VLR-BRUTO * 0.30 /* CALCULA 30% DO VALOR BRUTO
```

Tudo depois de `/*` na mesma linha também é comentário — é a segunda forma de comentar em Natural, muito usada para anotar campos no `DEFINE DATA`.

> [!IMPORTANT]
> Números literais (`500.00`, `0.30`, `0.075`) quase sempre representam regras: faixas, alíquotas, percentuais. Anote cada um que encontrar.

### 3.4. Chamada de outro módulo — `CALLNAT '<subprograma>'`

`CALLNAT` invoca um subprograma, equivalente a uma chamada de função. Os parâmetros vão na ordem definida pela PDA e podem ocupar várias linhas.

```natural
CALLNAT 'SUBVALCP' #PV-TIPO-DOC #PV-CPF #PV-NIS
                   #PV-COD-RETORNO #PV-MSG
                   #PV-IND-ESPECIAL
```

Tradução: "este módulo delega a validação de CPF ao subprograma `SUBVALCP.NSN` e recebe o resultado de volta em `#PV-COD-RETORNO` e `#PV-MSG`."

Registre cada `CALLNAT`, `INCLUDE` e `USING` no [`dependency-map.md`](../dependency-map.md).

### 3.5. Acesso a dados — `FIND` … `END-FIND`

```natural
FIND BENEFICIARIO-V WITH NUM-CPF = #CPF-STR
  IF NO RECORDS FOUND
    MOVE 'BENEFICIARIO NAO ENCONTRADO' TO #MSG
    MOVE 2001 TO #COD-RETORNO
  END-NOREC
  MOVE BENEFICIARIO-V.SIT-BENEFICIARIO   TO #SIT
  MOVE BENEFICIARIO-V.VLR-RENDA-FAMILIAR TO #RENDA
END-FIND
```

Leitura em voz alta: "procure o beneficiário com este CPF; se não encontrar, registre o erro; se encontrar, copie situação e renda para variáveis de trabalho."

Três coisas para levar:

- **`IF NO RECORDS FOUND` … `END-NOREC` é a forma idiomática de tratar "não achei".** O bloco executa uma única vez, quando a busca não retorna nenhum registro.
- **Os campos da view (`BENEFICIARIO-V.xxx`) só valem dentro do bloco `FIND`.** Por isso o padrão é copiá-los para `#variáveis` antes do `END-FIND`.
- Em módulos mais antigos aparecem variações com a mesma intenção: `IF *NUMBER(BENEFICIARIO-V) = 0`, ou uma flag lógica (`1 #FOUND-B (L)`) marcada dentro do `FIND` e testada depois. A diferença de estilo costuma indicar épocas diferentes de manutenção — anote a data do cabeçalho.

---

## 4. O que ignorar sem culpa

| Construção | O que é | Por que pular |
|---|---|---|
| `READ … BY …` / `END-READ` | Loop sobre registros Adabas | A regra está no `IF` dentro do loop |
| `WRITE` / `DISPLAY` / `PRINT` | Saída em tela ou relatório | Apresentação, não decisão |
| `FORMAT`, `WRITE TITLE`, `AT TOP OF PAGE`, `DEFINE PRINTER` | Formatação de relatório | Cosmética |
| `INPUT` | Leitura de terminal 3270 | Vai virar formulário web |
| `RESET INITIAL` | Inicializa variável | Detalhe técnico |
| `STORE` / `UPDATE` / `DELETE` | Persistência no Adabas | A regra é o `IF` antes; o `STORE` é só "salvar" |
| `END TRANSACTION` / `BACKOUT TRANSACTION` | Controle de commit | Infraestrutura de banco |
| `ON ERROR` / `END-ERROR` | Tratamento de erro técnico | Não é regra de negócio |
| `END-WORK` / `AT END OF DATA` | Fim de processamento | Estrutura, não regra |

> [!WARNING]
> `CALLNAT`, `INCLUDE` e `USING` **não** entram nesta lista. Eles são dependências e vão para o mapa.

---

## 5. Extraindo uma regra em 5 passos

Use `CALCDSCT.NSN` como exemplo.

### Passo 1 — Ler o cabeçalho (1 min)

```natural
* PROGRAMA: CALCDSCT
* OBJETIVO: CALCULO DESCONTOS E DEDUCOES DO BENEFICIO
* ALTERADO: 12/04/2007 - MARCIA HELENA - INC DESC JUDICIAL
```

Anote no `business-rules-catalog.md`: "CALCDSCT calcula descontos. Alterado em 2007 para incluir desconto judicial — possível regra especial."

### Passo 2 — Passar pelo `DEFINE DATA` (30 s)

Anote duas coisas: as linhas `USING` e `VIEW OF` (de onde vêm os dados) e os nomes de variáveis que sugerem valor (`VLR-BRUTO`, `TIPO-DSCT`).

### Passo 3 — Procurar os `IF` (3–5 min)

Use Ctrl+F no VS Code e digite `IF`. Cada `IF` é uma regra candidata.

| Linha | Condição | Possível regra |
|---|---|---|
| L142 | `IF #TIPO-DSCT NE 'J'` | Tratamento especial para descontos judiciais |
| L143 | `IF #VLR-TOTAL-DSCT > (#VLR-BRUTO * 0.30)` | Teto de 30% no desconto |

### Passo 4 — Procurar constantes numéricas (2 min)

Use Ctrl+F com `0.` para localizar `0.30`, `0.075` etc. Cada constante sem explicação é provavelmente uma alíquota ou percentual de regra. Busque também por `INIT <`: as tabelas paramétricas carregam faixas e fatores inteiros de uma vez.

### Passo 5 — Confirmar com Copilot Chat (2 min)

Selecione um bloco de código no VS Code, abra Copilot Chat (modo Ask) e envie:

> "Explique este trecho Natural em português. Foque na regra de negócio. Ignore entrada e saída."

Compare a explicação do Copilot com a sua interpretação. Se bater, registre no catálogo.

### Do `.NSN` à linha do catálogo

Para cada condicional, descreva apenas o comportamento que a equipe confirmou. Registre a evidência sem completar intenções que não estejam explícitas no código:

| ID | Regra | Programa Fonte | Risco |
|---|---|---|---|
| BR-XXX | Comportamento confirmado | `arquivo.NSN#L<início>-L<fim>` | Avaliar |

Uma condição ambígua deve ser registrada como pergunta em aberto em [`mysteries-found.md`](../mysteries-found.md), não convertida em regra.

---

## 6. Tipos e formatos de campo (DDM e variáveis)

> [!IMPORTANT]
> **Na especificação de formato, o separador decimal é a VÍRGULA.** `(N9,2)` significa 9 dígitos, dos quais 2 são decimais. A forma `(N9.2)`, com ponto, **não existe em Natural** — não compila. Se você vir um ponto dentro de um parêntese de formato, é erro de transcrição, não um dialeto antigo.
>
> A vírgula vale **só no formato**. Em valor literal dentro do código, o separador continua sendo o ponto: `MOVE 1.3500 TO #FATOR-REAJ` e `COMPUTE #VLR = #BRUTO * 0.30`.

### 6.1. Formatos que você vai encontrar

| Notação | Significado | Em PostgreSQL |
|---|---|---|
| `(A60)` | Alfanumérico, 60 caracteres | `VARCHAR(60)` |
| `(A11)` | Alfanumérico, 11 caracteres — é assim que CPF e NIS são guardados (preserva zeros à esquerda) | `CHAR(11)` |
| `(N11)` | Numérico *unpacked*, 11 dígitos, sem decimais | `NUMERIC(11)` |
| `(N8)` | Data no formato `AAAAMMDD` — Natural não tem tipo data aqui | `DATE` |
| `(N6)` | Competência no formato `AAAAMM`, ou hora `HHMMSS` | `INTEGER` (converter) |
| `(N9,2)` | Numérico *unpacked*, 9 dígitos, 2 decimais | `NUMERIC(9,2)` |
| `(P9,2)` | *Packed decimal*, 9 dígitos, 2 decimais | `NUMERIC(9,2)` |
| `(P13,2)` | *Packed decimal*, 13 dígitos, 2 decimais — acumulador de batch | `NUMERIC(13,2)` |
| `(N3,4)` | 3 dígitos, 4 decimais — típico de fator ou índice | `NUMERIC(3,4)` |
| `(L)` | Lógico (`TRUE` / `FALSE`) | `BOOLEAN` |

### 6.2. `P` (packed) × `N` (unpacked) — dinheiro é sempre `P`

| | `N` — *unpacked* | `P` — *packed decimal* |
|---|---|---|
| Armazenamento | 1 dígito por byte | 2 dígitos por byte; o último *nibble* guarda o sinal |
| Custo | maior espaço | menor espaço, aritmética mais rápida |
| Uso típico no SIFAP | contadores, códigos, datas `AAAAMMDD`, índices de laço | **valores monetários e fatores de cálculo** |

Em mainframe, dinheiro é *packed*. É o que o DDM diz — `CH VLR-RENDA-FAMILIAR P 9,2` — e é o que os programas declaram. Quando encontrar `(P9,2)`, `(P7,2)` ou `(P13,2)`, você está olhando para um campo de valor.

> [!TIP]
> Na modernização, `P` e `N` com decimais viram `BigDecimal` no Java e `NUMERIC(p,s)` no PostgreSQL. **Nunca** `double` ou `float`: o legado calcula em decimal exato, e a diferença aparece no centavo.

### 6.3. Arrays — a faixa de índices é explícita

| Notação | Significado |
|---|---|
| `(A60/1:10)` | 10 ocorrências de 60 caracteres |
| `(N3,4/1:27)` | 27 ocorrências de 3 dígitos com 4 decimais |
| `(P9,2/1:5)` | 5 ocorrências monetárias |
| `(N3,6/1:10,1:12)` | array bidimensional, 10 × 12 |

Os limites fazem parte da notação: escreve-se `1:27`, não apenas `27`. Arrays costumam vir acompanhados de `INIT <...>` — **cada número dessa lista é candidato a regra**. Dimensões contam história: 27 posições normalmente indexam UF, 12 indexam meses.

### 6.4. Estruturas Adabas que não cabem em uma coluna

| No DDM | Significado | Consequência |
|---|---|---|
| Coluna `T` = `M` (`MU`) | Campo multivalorado: vários valores no mesmo registro | **Vira tabela filha** |
| Coluna `T` = `P` (`PE`) | Grupo periódico: sub-registros repetidos | **Vira tabela filha** |

> [!WARNING]
> `MU` (multiple value) e `PE` (periodic group) são as únicas construções do Adabas que não cabem diretamente em PostgreSQL. Sempre que encontrar, marque no mapa de dependências — elas viram tabelas separadas no Estágio 3.

---

## 7. Lendo a listagem de um DDM

Os arquivos `.ddm` são listagens do utilitário `LISTDDM` — saída de máquina, não fonte editável. A tabela central tem sempre as mesmas colunas:

```text
 T L DB Name                     F Leng  S D Remark
 - - -- ------------------------ - ----  - - ---------------------------
   1 AB NUM-CPF                  A   11    U CPF SEM FORMATACAO
   1 CH VLR-RENDA-FAMILIAR       P  9,2  N   RENDA DECLARADA
 P 1 DA GRP-DEPENDENTE                        (1:10) GRUPO PERIODICO
   2 DC NOME-DEPENDENTE          A   60  N
 S   S2 SUPER-UF-SIT             A    3    S
        /* BG(1-2), CE(1-1)
```

| Coluna | Lê-se |
|---|---|
| `T` | Tipo: *(branco)* elementar · `G` grupo · `M` multivalorado (`MU`) · `P` grupo periódico (`PE`) · `S` descritor derivado |
| `L` | Nível: `1` campo raiz · `2` campo dentro de grupo ou PE |
| `DB` | *Short name* de 2 bytes — o nome físico que o Adabas conhece |
| `Name` | Nome longo — é este que aparece nas `VIEW OF` dos programas |
| `F` | Formato: `A` alfanumérico · `N` numérico *unpacked* · `P` *packed decimal* |
| `Leng` | Comprimento em bytes; com decimais vem `dígitos,decimais` (`9,2`) |
| `S` | Armazenamento: `N` *null suppression* · `F` *fixed storage* |
| `D` | Índice: `D` descritor · `U` único · `S` super · `H` hyper · `P` fonético · *(branco)* não indexado |

A linha iniciada por `/*` logo abaixo de um descritor derivado lista **os campos que o compõem**. No exemplo, `SUPER-UF-SIT` é a concatenação dos 2 primeiros bytes de `BG` (UF) com o primeiro byte de `CE` (situação) — o equivalente a um índice composto.

### 7.1. `FIND ... WITH` só é legal em descritor

`FIND` pesquisa pelo índice do Adabas. Portanto `FIND <view> WITH <campo>` **só funciona se o campo tiver algo na coluna `D`** (`D`, `U`, `S`, `H` ou `P`). Campo sem índice não é pesquisável.

| Campo em `BENEFICIARIO.ddm` | Coluna `D` | `FIND ... WITH` é legal? |
|---|---|---|
| `AB NUM-CPF` | `U` | sim |
| `CE SIT-BENEFICIARIO` | `D` | sim |
| `CH VLR-RENDA-FAMILIAR` | *(branco)* | **não** |
| `AD NOME-MAE` | *(branco)* | **não** |

Sem descritor, o programa precisa de outro caminho — tipicamente `READ <view> BY <descritor>` com um `IF` filtrando dentro do loop.

**Como conferir em 15 segundos:** abra o `.ddm`, use Ctrl+F no nome do campo e olhe a coluna imediatamente antes do `Remark`.

A legenda completa das colunas está no rodapé de cada `.ddm` e no [README dos DDMs](adabas-ddms/README.md).

---

## 8. Atalhos do VS Code que economizam tempo

<details>
<summary><strong>Tabela de atalhos e dicas de uso do Copilot Chat</strong></summary>

| Atalho | O que faz |
|---|---|
| Ctrl+F | Buscar dentro do arquivo |
| Ctrl+Shift+F | Buscar em todos os arquivos |
| Ctrl+G + número | Pular para a linha N |
| Selecionar + Copilot Chat | Enviar trecho diretamente para análise |

> [!TIP]
> Selecione o programa Natural inteiro, abra Copilot Chat e envie: "Liste todas as regras de negócio neste programa Natural. Para cada uma, indique o intervalo de linhas, a condição em português e o nível de risco (CRITICO/ALTO/MEDIO/BAIXO)." Em 30 segundos você tem 80% do trabalho feito. Confirme sempre olhando o `IF` original.

</details>

---

## 9. Mapa dos 15 programas — guia de leitura

| Categoria | Programas | O que esperar |
|---|---|---|
| Cadastro | `CADBENEF`, `CADDEPEND`, `CADPROG` | Telas de entrada. Validações de CPF, nome, datas. |
| Cálculo | `CALCBENF`, `CALCCORR`, `CALCDSCT` | Fórmulas e constantes. Onde mora a maioria das regras financeiras. |
| Validação | `VALBENEF`, `VALDOCS`, `VALELEG` | Sequências de `IF`. Cada um vira um teste. |
| Batch | `BATCHPGT`, `BATCHREL`, `BATCHCON` | Vários `CALLNAT`. Revela o fluxo de negócio. |
| Consulta e relatório | `CONSBENF`, `RELPGT`, `RELAUDIT` | Muito `READ`/`WRITE`. Poucas regras — leitura rápida. |

> [!NOTE]
> A pasta `natural-programs/` também contém **membros de apoio** (PDA, LDA, copycode, subprograma e JCL). Eles são infraestrutura compartilhada: você os consulta quando um dos seus 3 programas faz `USING`, `INCLUDE` ou `CALLNAT`, mas **não são leitura atribuída**. O inventário completo está no [README dos programas Natural](natural-programs/README.md).

---

## 10. Erros comuns de leitura

| Erro | Correção |
|---|---|
| Tentar entender cada linha | Focar apenas em `IF`, `COMPUTE` com constantes e comentários. |
| Ler na ordem do arquivo | Ir direto aos `IF` via Ctrl+F. |
| Confundir variável (`#VLR`) com campo de DDM (`VLR-BRUTO`) | `#` no início = variável local. Sem `#` = campo do banco. |
| Achar que todo `MOVE` é regra | `MOVE` é atribuição. A regra é o `IF` que decidiu o `MOVE`. |
| Copiar o formato com ponto (`(N9.2)`) para a documentação | O separador decimal do formato é vírgula: `(N9,2)`, `(P13,2)`. |
| Tratar `(P9,2)` como algo diferente de dinheiro | `P` é *packed decimal*: é o formato monetário do mainframe. |
| Anotar campo de view lido fora do bloco `FIND` | Confira se o valor foi copiado para `#variável` antes do `END-FIND`. |
| Anotar regra sem citar linha | Sempre registrar `arquivo.NSN#L<início>-L<fim>`. Sem isso o CI rejeita. |

---

## 11. Quando pedir ajuda

Se em 45 minutos você não conseguiu extrair pelo menos uma regra de um programa:

1. Sinalize ao facilitador.
2. Mostre o programa que está lendo.
3. Pergunte: "Que `IF` aqui é regra de negócio e qual é só técnico?"

---

### Continuar a leitura

| Anterior | Próximo |
|---|---|
| [Legado SIFAP — visão geral](README.md)<br/><sub>Contexto do sistema e inventário completo.</sub> | [GUIDE do Estágio 1](../GUIDE.md)<br/><sub>Roteiro cronometrado de 90 min.</sub> |

<sub>[Voltar ao índice do kit](../README.md)</sub>
