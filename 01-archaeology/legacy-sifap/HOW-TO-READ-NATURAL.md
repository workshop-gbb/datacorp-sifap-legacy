# How to Read a Natural Program Without Knowing Natural

> **Path:** [Team Kit](../../README.md) › [Stage 1](../README.md) › [SIFAP Legacy](README.md) › **How to read Natural**

**A business-rule-oriented reading tutorial.** Learn to extract relevant behavior from a `.NSN` file in 45 minutes, even if you do not know the Natural language.

| Field | Value |
|---|---|
| **Audience** | PO, Tech Writer, business analyst, junior developer—anyone opening a `.NSN` during Stage 1 |
| **Prerequisites** | VS Code installed; access to the `legacy-sifap/natural-programs/` folder |
| **Estimated time** | 10 min for this guide + 45 min per program |
| **Stage** | Stage 1 — Archaeology |
| **Expected outcome** | At least one rule cataloged with `file.NSN#L<start>-L<end>` evidence |

> [!TIP]
> You only need to read five constructs: comments with `*` at the start of the line, `IF/END-IF`, `MOVE`, `COMPUTE`, and the `FIND`/`END-FIND` block. The rest of the syntax is technical structure that can be ignored when reading rules.

---

## 1. Visual anatomy of a Natural program

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

**Three zones:**

1. **Header** (lines with `*`): tells the program's history. Note authors and dates—they indicate when rules were added.
2. **`DEFINE DATA` … `END-DEFINE`**: declares the data. It starts with external areas (`USING`) and ends with local fields. You can skip it or scan it to identify which DDM fields the program uses.
3. **Body** (after `END-DEFINE`): **this is where the business logic lives**. This is what you want to extract.

> [!NOTE]
> In the source files (`.NSP`, `.NSN`, `.NSA`, `.NSL`, `.NSC`, `.NSD`), comments are in Portuguese **uppercase without accents**. This is intentional: the mainframe's 3270 terminal uses EBCDIC and does not represent accented characters reliably. This English Markdown documentation uses normal punctuation and capitalization.

---

## 2. Natural library members

A Natural program is almost never isolated. SIFAP, the Payment Inspection and Administration System, has programs as well as **data areas, copycodes, and subprograms**. You can identify each type by its file extension.

| Extension | Member type | Purpose | How it enters the program |
|---|---|---|---|
| `.NSP` | Program | Executable entry point—batch or online | run directly (`EXEC PGM=NATBATCH`, or entered at the terminal) |
| `.NSN` | Subprogram | Reusable logic with a parameter contract | `CALLNAT '<name>'` |
| `.NSS` | External subroutine | Shared routine called by name | `PERFORM <subroutine>` |
| `.NSA` | PDA—*Parameter Data Area* | Parameter contract between caller and callee | `PARAMETER USING <pda>` in the callee; `LOCAL USING <pda>` in the caller |
| `.NSL` | LDA—*Local Data Area* | Fields and tables shared by several modules | `LOCAL USING <lda>` |
| `.NSC` | Copycode | Code fragment inserted at compile time | `INCLUDE <copycode>` |
| `.NSM` | MAP | 3270 screen layout | `INPUT USING MAP '<map>'` |
| `.NSD` | DDM—*Data Definition Module* | How Natural sees an Adabas file | `VIEW OF <ddm>` in `DEFINE DATA` |
| `.jcl` | JCL z/OS | How the batch runs in production: jobs, files, scheduling | outside Natural—`EXEC PGM=NATBATCH` |

> [!IMPORTANT]
> **The extension identifies the member type, and the type determines how the module is invoked.** Confusing `.NSP` with `.NSN` is the most common mistake for Natural newcomers: a program cannot be a `CALLNAT` target, and a subprogram cannot be run directly. SIFAP has **12 programs** (`.NSP`) and **5 subprograms** (`.NSN`).

### 2.1. The four lines that create dependencies

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

| Line | Meaning | Member location |
|---|---|---|
| `CALLNAT 'X'` | calls subprogram `X` and passes parameters | `X.NSN` |
| `... USING Y` | uses data area `Y` | `Y.NSA` (PDA) or `Y.NSL` (LDA) |
| `INCLUDE Z` | inserts copycode `Z` at this point | `Z.NSC` |
| `PERFORM W` | runs a subroutine | internal (`DEFINE SUBROUTINE W` in the same file) or external `W.NSS` |

`PERFORM` normally stays within the module. **`CALLNAT` crosses the file boundary**—that is what matters to the dependency map.

> [!IMPORTANT]
> **A Natural library is flat.** All members live in the same library (`SIFAPPRD`) and are resolved **by name**, never by path. `CALLNAT`, `INCLUDE`, and `USING` do not take a folder—this is why the kit keeps everything in the single `natural-programs/` directory. Member names are limited to eight characters, which explains abbreviations such as `CALCBENF` and `LDASIFAP`.

---

## 3. Constructs that matter

### 3.1. Comment—`*` at the start of the line

Everything beginning with `*` is free text. Always read comments—they often explain the "why" behind a rule.

```natural
* CHECK DEDUCTION CAP
```

Meaning: "The program checks the deduction cap here."

> [!TIP]
> Comments often contain dates and initials (`* 2007 MH - INC JUDICIAL`). Each one is evidence that a rule was added at a particular point in history—and may still be valid.

### 3.2. Decision—`IF` … `END-IF`

This is the most important construct. **Every business rule is inside an `IF`.**

```natural
IF #TYPE-DISC NE 'J'
  IF #AMT-TOTAL-DISC > (#AMT-GROSS * 0.30)
    COMPUTE #AMT-TOTAL-DISC = #AMT-GROSS * 0.30
  END-IF
END-IF
```

Read aloud: "If the deduction type is not 'J' (judicial), and the total deductions exceed 30% of the gross amount, reduce the total to the 30% limit."

**Common operators:**

| Natural | Meaning |
|---|---|
| `EQ` or `=` | equal |
| `NE` or `<>` | not equal |
| `GT` or `>` | greater than |
| `LT` or `<` | less than |
| `GE` or `>=` | greater than or equal |
| `LE` or `<=` | less than or equal |
| `AND` | and |
| `OR` | or |

Rule extracted from the example: *"Non-judicial deductions (type other than J) are capped at 30% of the gross amount."*

### 3.3. Assignment—`MOVE` and `COMPUTE`

`MOVE` copies a value to a variable. `COMPUTE` performs a calculation.

```natural
MOVE *DATN TO #DT-TODAY               /* ASSIGNS TODAY'S DATE TO #DT-TODAY
MOVE 500.00 TO #BAND-CONTRIB(1)     /* ASSIGNS 500 TO THE FIRST RANGE
COMPUTE #VLR-MAX = #AMT-GROSS * 0.30 /* CALCULATES 30% OF THE GROSS AMOUNT
```

Everything after `/*` on the same line is also a comment—the second way to write comments in Natural, often used to annotate fields in `DEFINE DATA`.

> [!IMPORTANT]
> Numeric literals (`500.00`, `0.30`, `0.075`) almost always represent rules: ranges, rates, or percentages. Record every one you find.

### 3.4. Calling another module—`CALLNAT '<subprograma>'`

`CALLNAT` invokes a subprogram, equivalent to a function call. Parameters follow the order defined by the PDA and may span several lines.

```natural
CALLNAT 'SUBVALCP' #PV-TYPE-DOC #PV-CPF #PV-NIS
                   #PV-COD-RETURN #PV-MSG
                   #PV-IND-SPECIAL
```

Meaning: "This module delegates CPF validation to the `SUBVALCP.NSN` subprogram and receives the result in `#PV-COD-RETURN` and `#PV-MSG`."

Record every `CALLNAT`, `INCLUDE`, and `USING` in [`dependency-map.md`](../dependency-map.md).

### 3.5. Data access—`FIND` … `END-FIND`

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

Read aloud: "Find the beneficiary with this CPF; if none is found, record the error; if found, copy status and income to working variables."

Three key points:

- **`IF NO RECORDS FOUND` … `END-NOREC` is the idiomatic way to handle "not found."** The block runs once when the search returns no records.
- **View fields (`BENEFICIARY-V.xxx`) are valid only within the `FIND` block.** This is why the usual pattern copies them to `#variables` before `END-FIND`.
- Older modules use variations with the same intent: `IF *NUMBER(BENEFICIARY-V) = 0`, or a logical flag (`1 #FOUND-B (L)`) set inside the `FIND` and tested afterward. Style differences often indicate different maintenance periods—note the header date.

---

## 4. What you can safely ignore

| Construct | What it is | Why to skip it |
|---|---|---|
| `READ … BY …` / `END-READ` | Loop over Adabas records | The rule is in the `IF` inside the loop |
| `WRITE` / `DISPLAY` / `PRINT` | Screen or report output | Presentation, not a decision |
| `FORMAT`, `WRITE TITLE`, `AT TOP OF PAGE`, `DEFINE PRINTER` | Report formatting | Cosmetic |
| `INPUT` | Reads from a 3270 terminal | It will become a web form |
| `RESET INITIAL` | Initializes a variable | Technical detail |
| `STORE` / `UPDATE` / `DELETE` | Adabas persistence | The rule is the preceding `IF`; `STORE` only means "save" |
| `END TRANSACTION` / `BACKOUT TRANSACTION` | Commit control | Database infrastructure |
| `ON ERROR` / `END-ERROR` | Technical error handling | Not a business rule |
| `END-WORK` / `AT END OF DATA` | End of processing | Structure, not a rule |

> [!WARNING]
> `CALLNAT`, `INCLUDE`, and `USING` are **not** on this list. They are dependencies and belong in the map.

---

## 5. Extracting a rule in five steps

Use `CALCDSCT.NSP` as the example.

### Step 1—Read the header (1 min)

```natural
* PROGRAM: CALCDSCT
* PURPOSE: CALCULATE BENEFIT DEDUCTIONS
* CHANGED: 12/04/2007 - MARCIA HELENA - ADD JUDICIAL DEDUCTION
```

Record in `business-rules-catalog.md`: "CALCDSCT calculates deductions. Changed in 2007 to add judicial deductions—possible special rule."

### Step 2—Scan `DEFINE DATA` (30 sec)

Note two things: the `USING` and `VIEW OF` lines (where the data comes from), and variable names that suggest values (`AMT-GROSS`, `TIPO-DSCT`).

### Step 3—Find the `IF` statements (3–5 min)

Use Ctrl+F in VS Code and enter `IF`. Each `IF` is a candidate rule.

| Line | Condition | Possible rule |
|---|---|---|
| L142 | `IF #TYPE-DISC NE 'J'` | Special handling for judicial deductions |
| L143 | `IF #AMT-TOTAL-DISC > (#AMT-GROSS * 0.30)` | 30% deduction cap |

### Step 4—Find numeric constants (2 min)

Use Ctrl+F with `0.` to locate `0.30`, `0.075`, and similar values. Each unexplained constant is probably a rule rate or percentage. Also search for `INIT <`: parameter tables load entire ranges and factors at once.

### Step 5—Confirm with Copilot Chat (2 min)

Select a code block in VS Code, open Copilot Chat (Ask mode), and send:

> "Explain this Natural code in English. Focus on the business rule. Ignore input and output."

Compare Copilot's explanation with your interpretation. If they match, record it in the catalog.

### From `.NSN` to a catalog entry

For each conditional, describe only the behavior confirmed by the team. Record the evidence without inventing intent that is not explicit in the code:

| ID | Rule | Source Program | Risk |
|---|---|---|---|
| BR-XXX | Confirmed behavior | `file.NSN#L<start>-L<end>` | Assess |

An ambiguous condition should be recorded as an open question in [`mysteries-found.md`](../mysteries-found.md), not converted into a rule.

---

## 6. Field types and formats (DDMs and variables)

> [!IMPORTANT]
> **In this lab, the decimal separator in a Natural source format specification is a period.** Natural Community Edition 9.3.3 compiles `(N9.2)` and `(P9.2)`. It rejects comma forms such as `(N9,2)` and `(P9,2)` with `NAT0165`.
>
> Natural installations can vary by decimal-character setting, and older mainframe installations commonly used a comma. This workshop follows the Natural CE 9.3.3 image. `DC=,` is not a workaround here because it collides with the `ID` delimiter and gives `NAT0385`.
>
> This rule applies **only to source declarations**. In literal values within code, the separator remains a period: `MOVE 1.3500 TO #FACTOR-ADJUST` and `COMPUTE #VLR = #BRUTO * 0.30`. DDM listings still print decimal lengths with a comma, for example `P  9,2`.

### 6.1. Formats you will encounter

| Notation | Meaning | In PostgreSQL |
|---|---|---|
| `(A60)` | Alphanumeric, 60 characters | `VARCHAR(60)` |
| `(A11)` | Alphanumeric, 11 characters—how CPF and NIS are stored (preserves leading zeros) | `CHAR(11)` |
| `(N11)` | *Unpacked* numeric, 11 digits, no decimal places | `NUMERIC(11)` |
| `(N8)` | Date in `AAAAMMDD` format—Natural has no date type here | `DATE` |
| `(N6)` | Reference period in `AAAAMM` format, or time in `HHMMSS` format | `INTEGER` (convert) |
| `(N9.2)` | *Unpacked* numeric, 9 digits, 2 decimal places | `NUMERIC(9,2)` |
| `(P9.2)` | *Packed decimal*, 9 digits, 2 decimal places | `NUMERIC(9,2)` |
| `(P13.2)` | *Packed decimal*, 13 digits, 2 decimal places—batch accumulator | `NUMERIC(13,2)` |
| `(N3.4)` | 3 digits, 4 decimal places—typical for a factor or index | `NUMERIC(3,4)` |
| `(L)` | Logical (`TRUE` / `FALSE`) | `BOOLEAN` |

### 6.2. `P` (packed) × `N` (unpacked)—money is always `P`

| | `N` — *unpacked* | `P` — *packed decimal* |
|---|---|---|
| Storage | 1 digit per byte | 2 digits per byte; the last *nibble* stores the sign |
| Cost | more space | less space, faster arithmetic |
| Typical SIFAP use | counters, codes, `AAAAMMDD` dates, loop indexes | **monetary values and calculation factors** |

On the mainframe, money is *packed*. That is what the DDM says—`CH AMT-FAMILY-INCOME P 9,2`—and what the programs declare. When you find `(P9.2)`, `(P7.2)`, or `(P13.2)` in Natural source, you are looking at a value field.

> [!TIP]
> During modernization, decimal `P` and `N` values become `BigDecimal` in Java and `NUMERIC(p,s)` in PostgreSQL. **Never** use `double` or `float`: the legacy system calculates exact decimals, and differences appear at the cent level.

### 6.3. Arrays—the index range is explicit

| Notation | Meaning |
|---|---|
| `(A60/1:10)` | 10 occurrences of 60 characters |
| `(N3.4/1:27)` | 27 occurrences of 3 digits with 4 decimal places |
| `(P9.2/1:5)` | 5 monetary occurrences |
| `(N3.6/1:10,1:12)` | two-dimensional array, 10 × 12 |

The bounds are part of the notation: write `1:27`, not just `27`. Arrays often appear with `INIT <...>`—**every number in that list is a candidate rule**. Dimensions tell a story: 27 positions usually index UF, while 12 index months.

### 6.4. Adabas structures that do not fit in one column

| In the DDM | Meaning | Consequence |
|---|---|---|
| Column `T` = `M` (`MU`) | Multiple-value field: several values in one record | **Becomes a child table** |
| Column `T` = `P` (`PE`) | Periodic group: repeated subrecords | **Becomes a child table** |

> [!WARNING]
> `MU` (multiple value) and `PE` (periodic group) are the only Adabas constructs that do not map directly to PostgreSQL. Whenever you find one, mark it in the dependency map—they become separate tables in Stage 3.

---

## 7. Reading a DDM listing

The `.ddm` files are listings from the `LISTDDM` utility—machine output, not editable source. The main table always has the same columns:

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

| Column | Read as |
|---|---|
| `T` | Type: *(blank)* elementary · `G` group · `M` multiple-value (`MU`) · `P` periodic group (`PE`) · `S` derived descriptor |
| `L` | Level: `1` root field · `2` field within a group or PE |
| `DB` | 2-byte *short name*—the physical name known by Adabas |
| `Name` | Long name—the one that appears in program `VIEW OF` declarations |
| `F` | Format: `A` alphanumeric · `N` *unpacked* numeric · `P` *packed decimal* |
| `Leng` | Length in bytes; decimals use `digits,decimals` (`9,2`) |
| `S` | Storage: `N` *null suppression* · `F` *fixed storage* |
| `D` | Index: `D` descriptor · `U` unique · `S` super · `H` hyper · `P` phonetic · *(blank)* not indexed |

The line beginning with `/*` immediately below a derived descriptor lists **the fields that compose it**. In the example, `SUPER-UF-STAT` concatenates the first two bytes of `BG` (UF) with the first byte of `CE` (status)—equivalent to a composite index.

### 7.1. `FIND ... WITH` is legal only on a descriptor

`FIND` searches through an Adabas index. Therefore, `FIND <view> WITH <field>` **works only if the field has a value in column `D`** (`D`, `U`, `S`, `H`, or `P`). A field without an index cannot be searched.

| Field in `BENEFIC.ddm` | Column `D` | Is `FIND ... WITH` legal? |
|---|---|---|
| `AB NUM-CPF` | `U` | yes |
| `CE STAT-BENEFICIARY` | `D` | yes |
| `CH AMT-FAMILY-INCOME` | *(blank)* | **no** |
| `AD MOTHER-NAME` | *(blank)* | **no** |

Without a descriptor, the program needs another path—typically `READ <view> BY <descriptor>` with an `IF` filtering inside the loop.

**How to check in 15 seconds:** open the `.ddm`, use Ctrl+F on the field name, and inspect the column immediately before `Remark`.

The complete column legend is in the footer of each `.ddm` and in the [DDM README](adabas-ddms/README.md).

---

## 8. Time-saving VS Code shortcuts

<details>
<summary><strong>Shortcut table and Copilot Chat usage tips</strong></summary>

| Shortcut | What it does |
|---|---|
| Ctrl+F | Search within the file |
| Ctrl+Shift+F | Search across all files |
| Ctrl+G + number | Go to line N |
| Select + Copilot Chat | Send a snippet directly for analysis |

> [!TIP]
> Select the entire Natural program, open Copilot Chat, and send: "List all business rules in this Natural program. For each one, provide the line range, the condition in English, and the risk level (CRITICAL/HIGH/MEDIUM/LOW)." In 30 seconds, 80% of the work is done. Always confirm by inspecting the original `IF`.

</details>

---

## 9. Map of the 15 programs—reading guide

| Category | Programs | What to expect |
|---|---|---|
| Registration | `CADBENEF`, `CADDEPEND`, `CADPROG` | Input screens. CPF, name, and date validations. |
| Calculation | `CALCBENF`, `CALCCORR`, `CALCDSCT` | Formulas and constants. Most financial rules live here. |
| Validation | `VALBENEF`, `VALDOCS`, `VALELEG` | Sequences of `IF` statements. Each becomes a test. |
| Batch | `BATCHPGT`, `BATCHREL`, `BATCHCON` | Many `CALLNAT` statements. Reveals the business flow. |
| Query and reporting | `CONSBENF`, `RELPGT`, `RELAUDIT` | Many `READ`/`WRITE` statements. Few rules—quick reading. |

> [!NOTE]
> The `natural-programs/` folder also contains **supporting members** (PDA, LDA, copycode, subprogram, and JCL). They are shared infrastructure: consult them when one of your three programs uses `USING`, `INCLUDE`, or `CALLNAT`, but they are **not assigned reading**. The complete inventory is in the [Natural programs README](natural-programs/README.md).

---

## 10. Common reading mistakes

| Mistake | Correction |
|---|---|
| Trying to understand every line | Focus only on `IF`, `COMPUTE` with constants, and comments. |
| Reading in file order | Go directly to the `IF` statements using Ctrl+F. |
| Confusing a variable (`#VLR`) with a DDM field (`AMT-GROSS`) | Leading `#` = local variable. No `#` = database field. |
| Assuming every `MOVE` is a rule | `MOVE` is assignment. The rule is the `IF` that selected the `MOVE`. |
| Copying a DDM-listing comma form (`P 9,2`) into Natural source documentation | Source declarations use a period in this lab: `(N9.2)`, `(P13.2)`. |
| Treating `(P9.2)` as something other than money | `P` is *packed decimal*: the mainframe monetary format. |
| Recording a view field read outside the `FIND` block | Check whether the value was copied to a `#variable` before `END-FIND`. |
| Recording a rule without a line citation | Always record `file.NSN#L<start>-L<end>`. CI rejects entries without it. |

---

## 11. When to ask for help

If you cannot extract at least one rule from a program within 45 minutes:

1. Notify the facilitator.
2. Show the program you are reading.
3. Ask: "Which `IF` here is a business rule, and which is only technical?"

---

### Continue reading

| Previous | Next |
|---|---|
| [SIFAP Legacy—overview](README.md)<br/><sub>System context and complete inventory.</sub> | [Stage 1 GUIDE](../GUIDE.md)<br/><sub>Timed 90-minute walkthrough.</sub> |

<sub>[Back to the kit index](../README.md)</sub>
