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
> Você só precisa ler 4 construções: `IF/END-IF`, `MOVE`, `COMPUTE` e os comentários com `*` no início da linha. O restante da sintaxe é estrutura técnica que pode ser ignorada na leitura de regras.

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

DEFINE DATA                                                          <- DECLARACAO DE VARIAVEIS
LOCAL                                                                  Apenas da nome aos campos
  1 PAGAMENTO-V VIEW OF PAGAMENTO                                      que o programa vai usar.
    2 NUM-PAGTO        (N10)                                           Pode pular — so anote os
    2 VLR-BRUTO        (N9.2)                                          campos que aparecem em
    2 VLR-DESCONTO     (N9.2)                                          tabela (DDM).
  1 #VLR-MAX-DSCT      (N9.2)
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
2. **`DEFINE DATA` … `END-DEFINE`**: declara variáveis. Pode pular, ou olhar para identificar quais campos do DDM o programa usa.
3. **Corpo** (depois de `END-DEFINE`): **aqui está a lógica de negócio**. É o que você quer extrair.

---

## 2. As 4 construções que importam

### 2.1 Comentário — `*` no início da linha

Tudo que começa com `*` é texto livre. Leia sempre os comentários — frequentemente eles explicam o "porquê" da regra.

```natural
* CHECK DEDUCTION CAP
```

Tradução: "Aqui o programa verifica o teto do desconto."

> [!TIP]
> Comentários frequentemente têm datas e iniciais (`* 2007 MH - INC JUDICIAL`). Cada uma é evidência de que uma regra foi adicionada em um momento histórico — e ainda pode estar válida.

### 2.2 Decisão — `IF` … `END-IF`

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

### 2.3 Atribuição — `MOVE` e `COMPUTE`

`MOVE` copia um valor para uma variável. `COMPUTE` faz uma conta.

```natural
MOVE *DATN TO #DT-HOJE              <- Atribui a data de hoje a #DT-HOJE
MOVE 500.00 TO #FAIXA-CONTRIB(1)    <- Atribui 500 à faixa 1
COMPUTE #VLR-MAX = #VLR-BRUTO * 0.30 <- Calcula 30% do valor bruto
```

> [!IMPORTANT]
> Números literais (`500.00`, `0.30`, `0.075`) quase sempre representam regras: faixas, alíquotas, percentuais. Anote cada um que encontrar.

### 2.4 Chamada de programa — `CALLNAT 'NOMEPGM'`

`CALLNAT` chama outro programa Natural, equivalente a uma chamada de função.

```natural
CALLNAT 'VALELEG' #CPF #STATUS
```

Tradução: "Este programa depende de `VALELEG.NSN`."

Registre cada `CALLNAT` no [`dependency-map.md`](../dependency-map.md).

---

## 3. O que ignorar sem culpa

| Construção | O que é | Por que pular |
|---|---|---|
| `READ … BY …` / `END-READ` | Loop sobre registros Adabas | A regra está no `IF` dentro do loop |
| `WRITE` / `DISPLAY` | Saída em tela ou relatório | Apresentação, não decisão |
| `FORMAT`, `WRITE TITLE` | Formatação de relatório | Cosmética |
| `INPUT` | Leitura de terminal 3270 | Vai virar formulário web |
| `RESET INITIAL` | Inicializa variável | Detalhe técnico |
| `STORE` / `UPDATE` / `DELETE` | Persistência no Adabas | A regra é o `IF` antes; o `STORE` é só "salvar" |
| `END-WORK` / `AT END OF DATA` | Fim de processamento | Estrutura, não regra |

---

## 4. Extraindo uma regra em 5 passos

Use `CALCDSCT.NSN` como exemplo.

### Passo 1 — Ler o cabeçalho (1 min)

```natural
* PROGRAMA: CALCDSCT
* OBJETIVO: CALCULO DESCONTOS E DEDUCOES DO BENEFICIO
* ALTERADO: 12/04/2007 - MARCIA HELENA - INC DESC JUDICIAL
```

Anote no `business-rules-catalog.md`: "CALCDSCT calcula descontos. Alterado em 2007 para incluir desconto judicial — possível regra especial."

### Passo 2 — Pular `DEFINE DATA` (30 s)

Dê uma olhada nos nomes das variáveis para se familiarizar (`VLR-BRUTO`, `VLR-DESCONTO`, `TIPO-DSCT`).

### Passo 3 — Procurar os `IF` (3–5 min)

Use Ctrl+F no VS Code e digite `IF`. Cada `IF` é uma regra candidata.

| Linha | Condição | Possível regra |
|---|---|---|
| L142 | `IF #TIPO-DSCT NE 'J'` | Tratamento especial para descontos judiciais |
| L143 | `IF #VLR-TOTAL-DSCT > (#VLR-BRUTO * 0.30)` | Teto de 30% no desconto |

### Passo 4 — Procurar constantes numéricas (2 min)

Use Ctrl+F com `0.` para localizar `0.30`, `0.075` etc. Cada constante sem explicação é provavelmente uma alíquota ou percentual de regra.

### Passo 5 — Confirmar com Copilot Chat (2 min)

Selecione um bloco de código no VS Code, abra Copilot Chat (modo Ask) e envie:

> "Explique este trecho Natural em português. Foque na regra de negócio. Ignore entrada e saída."

Compare a explicação do Copilot com a sua interpretação. Se bater, registre no catálogo.

---

## 5. Do `.NSN` à linha do catálogo

Para cada condicional, descreva apenas o comportamento que a equipe confirmou. Registre a evidência sem completar intenções que não estejam explícitas no código:

| ID | Regra | Programa Fonte | Risco |
|---|---|---|---|
| BR-XXX | Comportamento confirmado | `arquivo.NSN#L<início>-L<fim>` | Avaliar |

Uma condição ambígua deve ser registrada como pergunta em aberto em [`mysteries-found.md`](../mysteries-found.md), não convertida em regra.

---

## 6. Tabela de tipos de campo (DDM e variáveis)

| Notação | Significado | Em PostgreSQL |
|---|---|---|
| `(A60)` | Alfanumérico, 60 caracteres | `VARCHAR(60)` |
| `(N9.2)` | Numérico com 9 dígitos inteiros e 2 decimais | `NUMERIC(11,2)` |
| `(N10)` | Numérico inteiro com 10 dígitos | `BIGINT` |
| `(N8)` | Data no formato YYYYMMDD | `DATE` |
| `(L)` | Lógico (verdadeiro/falso) | `BOOLEAN` |
| `(MU)` | Multi-valor (múltiplos valores por registro) | **Vira tabela filha** |
| `(PE)` | Grupo periódico (sub-registros por exercício) | **Vira tabela filha** |

> [!WARNING]
> `MU` (multiple value) e `PE` (periodic group) são as únicas construções do Adabas que não cabem diretamente em PostgreSQL. Sempre que encontrar, marque no mapa de dependências — elas viram tabelas separadas no Estágio 3.

---

## 7. Atalhos do VS Code que economizam tempo

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

## 8. Mapa dos 15 programas — guia de leitura

| Categoria | Programas | O que esperar |
|---|---|---|
| Cadastro | `CADBENEF`, `CADDEPEND`, `CADPROG` | Telas de entrada. Validações de CPF, nome, datas. |
| Cálculo | `CALCBENF`, `CALCCORR`, `CALCDSCT` | Fórmulas e constantes. Onde mora a maioria das regras financeiras. |
| Validação | `VALBENEF`, `VALDOCS`, `VALELEG` | Sequências de `IF`. Cada um vira um teste. |
| Batch | `BATCHPGT`, `BATCHREL`, `BATCHCON` | Vários `CALLNAT`. Revela o fluxo de negócio. |
| Consulta e relatório | `CONSBENF`, `RELPGT`, `RELAUDIT` | Muito `READ`/`WRITE`. Poucas regras — leitura rápida. |

---

## 9. Erros comuns de leitura

| Erro | Correção |
|---|---|
| Tentar entender cada linha | Focar apenas em `IF`, `COMPUTE` com constantes e comentários. |
| Ler na ordem do arquivo | Ir direto aos `IF` via Ctrl+F. |
| Confundir variável (`#VLR`) com campo de DDM (`VLR-BRUTO`) | `#` no início = variável local. Sem `#` = campo do banco. |
| Achar que todo `MOVE` é regra | `MOVE` é atribuição. A regra é o `IF` que decidiu o `MOVE`. |
| Anotar regra sem citar linha | Sempre registrar `arquivo.NSN#L<início>-L<fim>`. Sem isso o CI rejeita. |

---

## 10. Quando pedir ajuda

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
