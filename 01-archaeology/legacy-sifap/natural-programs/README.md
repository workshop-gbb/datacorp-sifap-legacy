<!-- markdownlint-disable MD013 MD033 MD041 -->

# Natural Programs

> **Path:** [Team Kit](../../../README.md) › [Stage 1](../../README.md) › [SIFAP Legacy](../README.md) › **Natural Programs**

**The 15 assigned Natural members for SIFAP, the Payment Inspection and Administration System, plus the nine supporting library members.** The programs implement the legacy system's business logic. Each pair reads three programs during Stage 1.

| Field | Value |
|---|---|
| **Audience** | All pairs—each pair reads its three assigned programs |
| **Prerequisites** | Read [`COMO-LER-NATURAL.md`](../COMO-LER-NATURAL.md) |
| **Stage** | Stage 1 — Archaeology |
| **Expected outcome** | Rules cataloged with `file.NSN#L<start>-L<end>` evidence and a dependency map started |

> [!NOTE]
> These files are read-only reference material. During Stage 1, pairs analyze the programs to extract business rules and map them to the modern system (Java 21 + Spring Boot).

---

## What is in this folder

| Group | Count | Extensions | What to do with them |
|---|---|---|---|
| **Assigned members** | 15 | `.NSP` (12 programs), `.NSN` (3 subprograms) | **Assigned reading.** Three per pair |
| **Supporting members** | 9 | `.NSA`, `.NSL`, `.NSC`, `.NSN`, `.jcl` | **Consult as needed.** Shared infrastructure |

> [!IMPORTANT]
> **Your reading workload has not changed: it remains three programs per pair.**
> The nine supporting members are library infrastructure—data areas, copycodes, two validation subprograms, and two JCLs. Open one when one of *your* programs uses `USING`, `INCLUDE`, or `CALLNAT` and you need to understand what that name means. They are **not** extra programs, **do not** belong to any pair, and **do not** count toward the three assigned readings.

Everything is kept in one directory because a Natural library is **flat**: `CALLNAT`, `INCLUDE`, and `USING` resolve members **by name**, never by path. See [`COMO-LER-NATURAL.md`, section 2](../COMO-LER-NATURAL.md#2-natural-library-members).

---

## 1. The 15 assigned programs—distribution by pair

| Pair | Program | Author | Year | Description |
|---|---|---|---|---|
| **1 · Vision** (PO + RE)—registration | `CADBENEF.NSP` | Roberto Meirelles | 1997 | Beneficiary registration—creation, update, deletion |
| | `CADDEPEND.NSP` | José A. Lima | 1998 | Registration of a dependent linked to the primary beneficiary |
| | `CADPROG.NSP` | Fernanda C. Oliveira | 1997 | Social program registration—parameters and value ranges |
| **2 · Architecture** (EA + SA)—batch | `BATCHPGT.NSP` | José A. Lima | 1999 | Batch payment—generates monthly payment cycles |
| | `BATCHREL.NSP` | José A. Lima | 1999 | Batch report—produces management reports |
| | `BATCHCON.NSP` | Patrícia H. Moura | 2002 | Batch reconciliation—reconciles payments with SIAFI |
| **3 · Implementation** (TL + Dev)—calculation | `CALCBENF.NSN` | Roberto Meirelles | 1998 | Calculates the benefit amount by program and range |
| | `CALCCORR.NSP` | Marcos A. Ferreira | 2005 | Calculates corrections and adjustments using annual indexes |
| | `CALCDSCT.NSP` | Marcos A. Ferreira | 2015 | Calculates legal deductions (payroll deductions, income tax) |
| **4 · Quality** (DBA + QA)—validation | `VALBENEF.NSN` | Roberto Meirelles | 1997 | Validates registration data (CPF, NIS) |
| | `VALDOCS.NSP` | Patrícia H. Moura | 2003 | Validates supporting documentation |
| | `VALELEG.NSN` | Fernanda C. Oliveira | 1999 | Validates eligibility against program rules |
| **5 · Operations** (DevOps + TW)—query and reporting | `CONSBENF.NSP` | Roberto Meirelles | 1997 | Queries beneficiaries using multiple criteria (3270 screen) |
| | `RELPGT.NSP` | Patrícia H. Moura | 2003 | Payment report by period, program, and UF |
| | `RELAUDIT.NSP` | Marcos A. Ferreira | 2005 | Audit report—events and discrepancies |

---

## 2. The nine supporting members—shared infrastructure

None of these members belongs to a pair, and none counts as assigned reading.

| Member | Type | How it appears in code | Purpose |
|---|---|---|---|
| `PDAVALID.NSA` | PDA | `PARAMETER USING PDAVALID` / `LOCAL USING PDAVALID` | Parameter contract for the document-validation family: CPF and NIS are inputs; return code and message are outputs |
| `PDACALC.NSA` | PDA | `PARAMETER USING PDACALC` / `LOCAL USING PDACALC` | Parameter contract for the payment chain: beneficiary key and context are inputs; calculated amounts are outputs |
| `LDASIFAP.NSL` | LDA | `LOCAL USING LDASIFAP` | Shared parameter tables: regional factor, income ranges, rates, UF, dates, and the century window (Y2K) |
| `CCVALCPF.NSC` | Copycode | `INCLUDE CCVALCPF` + `PERFORM VALIDA-CPF-PADRAO` | CPF mod-11 routine inserted at compile time—the **old** validation path |
| `CCAUDIT.NSC` | Copycode | `INCLUDE CCAUDIT` + `PERFORM GRAVA-AUDITORIA` | Standard block for writing the audit trail to ARQ 153 |
| `SUBVALCP.NSN` | Subprogram | `CALLNAT 'SUBVALCP' ...` | Callable CPF validation (mod-11)—the **new** validation path |
| `SUBVALNI.NSN` | Subprogram | `CALLNAT 'SUBVALNI' ...` | Callable NIS/PIS/PASEP validation (mod-11) |
| `SIFAPJ01.jcl` | JCL z/OS | outside Natural | **Monthly payroll** job—runs `BATCHPGT` through `NATBATCH` |
| `SIFAPJ02.jcl` | JCL z/OS | outside Natural | **Monthly reporting** job—runs `BATCHREL` and `RELPGT` |

> [!NOTE]
> `SUBVALCP.NSN` and `SUBVALNI.NSN` have the `.NSN` extension like other assigned members, but they are **subprograms**: they exist only to be called by `CALLNAT` and do not perform `INPUT` or `WRITE`. They are not among the 15 assigned members.

---

## 3. From JCL to program—the production batch flow

The two JCLs make the monthly flow traceable end to end:

| Job | When it runs | What it runs | Output |
|---|---|---|---|
| `SIFAPJ01.jcl` | Monthly—first business day | `BATCHPGT` | Monthly payroll and bank remittance file |
| `SIFAPJ02.jcl` | Monthly—second business day, after `SIFAPJ01` | `BATCHREL` and `RELPGT` | Consolidated report and analytical report by program |

Each JCL documents the schedule (Control-M), allocated files, and restart procedure in comments. It is the best source for answering "what happens every month, and in what order?"

---

## 4. Dependency map—how to build it

The members in this folder reference one another. Discovering **who calls whom** is the Stage 1 dependency-mapping exercise: the result belongs in [`dependency-map.md`](../../dependency-map.md) and is not published here.

**The four edge types and how to find them:**

```bash
cd 01-arqueologia/legado-sifap/natural-programs

grep -n "CALLNAT" *.NSP *.NSN   # subprogram call         (edge between modules)
grep -n "INCLUDE" *.NSP *.NSN   # inserted copycode       (edge to .NSC)
grep -n "USING"   *.NSP *.NSN   # PDA and LDA in use      (edge to .NSA/.NSL)
grep -n -A 8 "CMSYNIN" *.jcl     # program run by each job
```

In VS Code, the equivalent is Ctrl+Shift+F with the regular expression `CALLNAT|INCLUDE|USING` and the file filter `*.NSP,*.NSN`.

**What to record for each edge found:**

| Field | Example |
|---|---|
| Source | `BATCHPGT` |
| Type | `CALLNAT` · `INCLUDE` · `USING` · `JCL runs` |
| Target | called member name |
| Evidence | `file.NSN#L<line>` |

> [!TIP]
> Three time-saving guidelines:
>
> 1. **Confirm every edge in the code.** A header comment is a clue, not proof: it may mention a dependency that is absent from the program body or omit one that is present.
> 2. **Some edges cross pairs.** If one of your programs calls a program assigned to another pair, coordinate the reading with that pair before finalizing the map—this is how the system design emerges.
> 3. **Start with supporting members.** Searching the entire directory for `SUBVALCP`, `SUBVALNI`, `CCVALCPF`, `CCAUDIT`, `PDAVALID`, `PDACALC`, and `LDASIFAP` reveals the graph skeleton in minutes.

---

### Continue reading

| Previous | Next |
|---|---|
| [SIFAP Legacy—overview](../README.md)<br/><sub>System context and history.</sub> | [Adabas DDMs](../adabas-ddms/README.md)<br/><sub>Adabas data structures.</sub> |

<sub>[Back to the kit index](../../../README.md)</sub>
