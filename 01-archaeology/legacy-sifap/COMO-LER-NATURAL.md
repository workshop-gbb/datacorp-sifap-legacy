<!-- markdownlint-disable MD013 MD025 MD026 MD028 MD029 MD034 MD040 MD051 MD060 -->

# Como Ler um Programa Natural Sem Saber Natural

![GUIA Natural sem ser dev](https://img.shields.io/badge/GUIA-Natural%20sem%20ser%20dev-F25022?style=for-the-badge) ![DURAÇÃO 10 min](https://img.shields.io/badge/DURAÇÃO-10%20min-1A1A1A?style=for-the-badge) ![USE Antes do S1](https://img.shields.io/badge/USE-Antes%20do%20S1-737373?style=for-the-badge)

> 🗺 **Você está aqui:** [Kit PT-BR](../../README.md) → [Estágio 1](../README.md) → [Legado](README.md) → **Como ler Natural**

> **Para quem é isto?** Para você (PO, Tech Writer, analista de negócio, dev junior, qualquer um) que vai abrir um arquivo `.NSN` no Estágio 1 e precisa **extrair as regras de negócio** sem ficar perdido na sintaxe.
>
> **Spoiler:** você só precisa ler 4 construções: `IF/END-IF`, `MOVE`, `COMPUTE` e os comentários `*`. O resto é decoração.

---

## 1. Anatomia visual de um programa Natural

```
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *    ← CABEÇALHO (comentários)
* PROGRAMA: CALCDSCT                                                  Toda linha com * é comentário.
* SISTEMA:  SIFAP - SIST. FISC. ADM. PAGAMENTOS                       Leia aqui o histórico do
* AUTOR:    ROBERTO MENDES JUNIOR                                     programa: quem mexeu e
* DATA:     25/08/1999                                                quando. Pistas valiosas.
* ALTERADO: 12/04/2007 - MARCIA HELENA - INC DESC JUDICIAL
* OBJETIVO: CALCULO DESCONTOS E DEDUCOES DO BENEFICIO
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

DEFINE DATA                                                          ← DECLARAÇÃO DE VARIÁVEIS
LOCAL                                                                  Apenas dá nome aos campos
  1 PAGAMENTO-V VIEW OF PAGAMENTO                                      que o programa vai usar.
    2 NUM-PAGTO        (N10)                                           Pode pular — só anote os
    2 VLR-BRUTO        (N9.2)                                          campos que aparecem em
    2 VLR-DESCONTO     (N9.2)                                          tabela (DDM).
  1 #VLR-MAX-DSCT      (N9.2)
END-DEFINE
*
MOVE *DATN TO #DT-HOJE                                                ← CORPO DO PROGRAMA
*                                                                       Aqui mora a lógica.
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

1. **Cabeçalho** (linhas iniciadas com `*`): conta a história do programa. Anote autores e datas — eles indicam onde regras foram adicionadas.
2. **`DEFINE DATA` … `END-DEFINE`**: só declara variáveis. Você pode pular, ou olhar para identificar quais campos do DDM o programa toca.
3. **Corpo** (depois de `END-DEFINE`): **aqui está a lógica de negócio**. É o que você quer extrair.

---

## 2. As 4 construções que importam (e como traduzi-las)

### 2.1 Comentário · `*` no começo da linha

Tudo que começa com `*` é texto livre. **Leia sempre os comentários** — frequentemente eles dão o "porquê" da regra.

```natural
* CHECK DEDUCTION CAP
```

→ Tradução: "Aqui o programa verifica o teto do desconto."

> [!TIP]
> Comentários frequentemente têm datas e iniciais (`* 2007 MH - INC JUDICIAL`). Cada uma é uma evidência de que **uma regra foi adicionada num momento histórico** — e ela ainda pode estar válida.

### 2.2 Decisão · `IF` … `END-IF`

Esta é a construção mais importante. **Toda regra de negócio está dentro de um `IF`.**

```natural
IF #TIPO-DSCT NE 'J'
  IF #VLR-TOTAL-DSCT > (#VLR-BRUTO * 0.30)
    COMPUTE #VLR-TOTAL-DSCT = #VLR-BRUTO * 0.30
  END-IF
END-IF
```

**Como ler em voz alta:**

> Se o tipo de desconto **não é** 'J' (judicial), e se o valor total dos descontos é maior que 30% do valor bruto, então… (faça algo)

**Operadores comuns:**

| Natural | Significado |
|---|---|
| `EQ` ou `=` | igual |
| `NE` ou `≠` | diferente |
| `GT` ou `>` | maior |
| `LT` ou `<` | menor |
| `GE` ou `>=` | maior ou igual |
| `LE` ou `<=` | menor ou igual |
| `AND` | e |
| `OR` | ou |

→ **Regra extraída deste exemplo:** *"Descontos não judiciais (tipo ≠ J) têm teto de 30% do valor bruto."*

### 2.3 Atribuição · `MOVE` e `COMPUTE`

`MOVE` copia um valor para uma variável. `COMPUTE` faz uma conta.

```natural
MOVE *DATN TO #DT-HOJE              ← Põe a data de hoje em #DT-HOJE
MOVE 500.00 TO #FAIXA-CONTRIB(1)    ← Põe 500 na faixa 1
COMPUTE #VLR-MAX = #VLR-BRUTO * 0.30 ← Calcula 30% do bruto
```

> [!IMPORTANT]
> Quando você vê números mágicos (`500.00`, `0.30`, `0.075`), eles **quase sempre são regras**. Tabelas de faixas, alíquotas, percentuais — tudo está aqui. Anote.

### 2.4 Chamada de programa · `CALLNAT 'NOMEPGM'`

`CALLNAT` é uma chamada de função (chama outro programa Natural).

```natural
CALLNAT 'VALELEG' #CPF #STATUS
```

→ "Este programa **depende** do programa `VALELEG.NSN`."

> **Por que importar?** É como você descobre o **grafo de dependências** entre programas (Estágio 1 — `dependency-map.md`).

---

## 3. O que IGNORAR sem culpa

Estas construções **não são regra de negócio** — pule sem ler:

| Construção | O que é | Por que pular |
|---|---|---|
| `READ … BY …` / `END-READ` | Loop sobre registros do Adabas | É só "ler dados", a regra está no `IF` dentro |
| `WRITE` / `DISPLAY` | Imprime na tela ou no relatório | Saída visual, não decisão |
| `FORMAT`, `WRITE TITLE` | Formatação de relatório | Cosmética |
| `INPUT` | Lê do terminal 3270 | Vai virar formulário HTML — irrelevante hoje |
| `RESET INITIAL` | Inicializa variável | Detalhe técnico |
| `STORE` / `UPDATE` / `DELETE` | Persistência | A regra é o `IF` antes; o `STORE` é só "salvar" |
| `END-WORK` / `AT END OF DATA` | Fim de processamento | Estrutura, não regra |

---

## 4. Receita de bolo: extraindo uma regra em 5 passos

Suponha que você abriu `CALCDSCT.NSN`. Aqui está o passo a passo:

### Passo 1 — Leia o cabeçalho (1 min)

```natural
* PROGRAMA: CALCDSCT
* OBJETIVO: CALCULO DESCONTOS E DEDUCOES DO BENEFICIO
* ALTERADO: 12/04/2007 - MARCIA HELENA - INC DESC JUDICIAL
```

**Anote no `business-rules-catalog.md`:**

> Programa CALCDSCT calcula descontos. Alterado em 2007 para incluir desconto judicial — possível regra especial.

### Passo 2 — Pule `DEFINE DATA` (30s)

Só dê uma olhada nos nomes das variáveis para se familiarizar (`VLR-BRUTO`, `VLR-DESCONTO`, `TIPO-DSCT`).

### Passo 3 — Procure os `IF` (3–5 min)

Use o atalho do VS Code: <kbd>Ctrl</kbd>+<kbd>F</kbd> → digite `IF`.

Cada `IF` é uma regra candidata. Anote linha + condição:

| Linha | Condição | Possível regra |
|---|---|---|
| L142 | `IF #TIPO-DSCT NE 'J'` | Tratamento especial para descontos judiciais |
| L143 | `IF #VLR-TOTAL-DSCT > (#VLR-BRUTO * 0.30)` | Teto de 30% no desconto |

### Passo 4 — Procure constantes numéricas (2 min)

Use <kbd>Ctrl</kbd>+<kbd>F</kbd> com `0.` (procura `0.30`, `0.075`, etc.).

Cada constante sem explicação é provavelmente uma alíquota ou um percentual de regra.

### Passo 5 — Use o Copilot para confirmar (2 min)

Selecione um bloco de código no VS Code, abra Copilot Chat (modo Ask) e cole:

> *"Explique este trecho Natural em português. Foque na regra de negócio. Ignore IO."*

O Copilot vai traduzir. **Compare** com a sua interpretação. Se bate, escreva no catálogo.

---

## 5. Exemplo completo: do `.NSN` à linha do catálogo

### O que você vê em `CALCDSCT.NSN` (linhas 142-148):

```natural
* CHECK DEDUCTION CAP
IF #TIPO-DSCT NE 'J'
  IF #VLR-TOTAL-DSCT > (#VLR-BRUTO * 0.30)
    COMPUTE #VLR-TOTAL-DSCT = #VLR-BRUTO * 0.30
  END-IF
END-IF
```

### Tradução em linguagem natural:

> Se o tipo de desconto **não** é judicial (`NE 'J'`), e se o total já passou de 30% do valor bruto, então **trunca** o desconto em 30%.
>
> Em outras palavras: **descontos têm teto de 30%, EXCETO judiciais que não têm teto**.

### Linha que vai para o `business-rules-catalog.md`:

| ID | Regra | Programa Fonte | Risco |
|---|---|---|---|
| BR-013 | Desconto total ≤ 30% do bruto, exceto judiciais (tipo J) | `01-arqueologia/legado-sifap/natural-programs/CALCDSCT.NSN#L142-L148` | CRÍTICO |

Pronto. Você extraiu uma regra de negócio sem precisar saber programar em Natural.

---

## 6. Tabela de tradução de tipos de campo (DDM e variáveis)

Quando você abrir os DDMs ou as variáveis de um `.NSN`, vai ver coisas assim:

| Aparece | Significa | Em PostgreSQL fica |
|---|---|---|
| `(A60)` | Alfanumérico, 60 caracteres | `VARCHAR(60)` |
| `(N9.2)` | Numérico com 9 dígitos antes e 2 depois da vírgula (até 999.999.999,99) | `NUMERIC(11,2)` |
| `(N10)` | Numérico inteiro com 10 dígitos | `BIGINT` |
| `(N8)` | Data no formato YYYYMMDD | `DATE` |
| `(L)` | Lógico (TRUE/FALSE) | `BOOLEAN` |
| `(MU)` | Multi-valor (vários valores na mesma linha) | **Vira tabela filha** |
| `(PE)` | Grupo periódico (vários sub-registros) | **Vira tabela filha** |

> [!WARNING]
> `MU` e `PE` são as **únicas** coisas do Adabas que não cabem em PostgreSQL direto. Sempre que ver, marque — vira tabela separada no Estágio 3.

---

## 7. Atalhos do VS Code que economizam tempo

<details>
<summary><strong>Tabela de atalhos + dicas de uso do Copilot Chat</strong></summary>

| Atalho | O que faz |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>F</kbd> | Buscar dentro do arquivo |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>F</kbd> | Buscar em **todos** os arquivos |
| <kbd>Ctrl</kbd>+<kbd>G</kbd> + número | Pular para a linha N |
| `F2` | Renomear (não use em legado — só leia!) |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>→</kbd> | Próximo `IF` (se tiver navegação de símbolos) |
| Selecionar + Copilot Chat | Cola e pergunta direto sobre o trecho |

> [!TIP]
> **Atalho do Copilot Chat.** Selecione o programa Natural inteiro → abra Copilot Chat → cole:
>
> *"Liste todas as regras de negócio neste programa Natural. Para cada uma, indique o intervalo de linhas, a condição em português e o nível de risco (CRÍTICO/ALTO/MÉDIO/BAIXO)."*
>
> Em 30 segundos você tem 80% do trabalho feito. **Sempre confirme** olhando o `IF` original.

---

</details>

## 8. Mapa dos 15 programas — em uma olhada

| Categoria | Programas | O que esperar |
|---|---|---|
| **Cadastro** | `CADBENEF`, `CADDEPEND`, `CADPROG` | Telas de input. Validações de CPF, nome, datas |
| **Cálculo** | `CALCBENF`, `CALCCORR`, `CALCDSCT` | **Fórmulas e constantes.** Onde mora a maioria das regras financeiras |
| **Validação** | `VALBENEF`, `VALDOCS`, `VALELEG` | `IF` em sequência. Cada um vira um teste |
| **Batch** | `BATCHPGT`, `BATCHREL`, `BATCHCON` | Vários `CALLNAT`. Lê o **fluxo** de negócio |
| **Consulta/Relatório** | `CONSBENF`, `RELPGT`, `RELAUDIT` | Muito `READ`/`WRITE`. Pouca regra — pule rápido |

---

## 9. Erros comuns de leitura (e como evitar)

| ❌ Erro | ✅ Correção |
|---|---|
| Tentar entender cada linha | Foque só em `IF`, `COMPUTE` com constantes e comentários |
| Ler na ordem do arquivo | Vá direto para os `IF` (use <kbd>Ctrl</kbd>+<kbd>F</kbd>) |
| Confundir variável (`#VLR`) com campo de DDM (`VLR-BRUTO`) | `#` no início = variável local. Sem `#` = campo do banco |
| Achar que todo `MOVE` é regra | `MOVE` é só atribuição. Regra é o `IF` que decidiu o `MOVE` |
| Anotar regra sem citar linha | Sempre anote `arquivo.NSN#L<início>-L<fim>`. **Sem isso o CI rejeita.** |

---

## 10. Quando pedir ajuda

Se em **45 minutos** você não conseguiu extrair pelo menos 1 regra de um programa:

1. Levante a mão para o facilitador.
2. Mostre o programa que está lendo.
3. Pergunte: *"Que `IF` aqui é regra de negócio e qual é só técnico?"*

Esse pedido nunca atrapalha — é o trabalho do facilitador.

---

### Continuar a leitura

<table width="100%">
<tr>
<td width="50%" valign="top" align="left">
<sub><strong>← ANTERIOR</strong></sub><br/>
<a href="../07-conceitos/03-glossario-visual.md"><strong>Glossário Visual</strong></a><br/>
<sub>30+ termos técnicos com analogia em 3 linhas.</sub>
</td>
<td width="50%" valign="top" align="right">
<sub><strong>PRÓXIMO →</strong></sub><br/>
<a href="../01-arqueologia/GUIDE.md"><strong>Estágio 1 — Arqueologia</strong></a><br/>
<sub>11:00–12:00 + 13:30–14:00 · Ler o legado e catalogar regras de negócio.</sub>
</td>
</tr>
</table>

<sub>↑ <a href="../README.md">Voltar ao Kit PT-BR</a></sub>
