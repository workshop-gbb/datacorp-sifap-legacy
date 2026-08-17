---
description: "Reading guide for Natural/Adabas legacy code — language patterns, FDT structure, naming conventions, batch flows"
applyTo: "01-arqueologia/legado-sifap/**,**/*.NSP,**/*.nsp,**/*.NSN,**/*.nsn,**/*.NSS,**/*.nss,**/*.NSA,**/*.nsa,**/*.NSL,**/*.nsl,**/*.NSC,**/*.nsc,**/*.NSM,**/*.nsm,**/*.NSD,**/*.nsd,**/*.NAT,**/*.nat,**/*.CPY,**/*.cpy,**/*.DDM,**/*.ddm,**/*.jcl,**/*.JCL"
---

# Natural/Adabas Legacy Code — Reading Guide

This file is activated when you open Natural programs, Adabas DDMs, or any file within the `01-arqueologia/legado-sifap/` directory. It teaches you how to read legacy code — it does not interpret any specific system for you.

## Natural Program Structure

A Natural program follows this skeleton:

```
DEFINE DATA
  LOCAL
    01 #MY-VARIABLE  (A20)    /* A = alphanumeric, 20 chars */
    01 #COUNTER      (N5)     /* N = numeric, 5 digits */
    01 #AMOUNT       (P9,2)   /* P = packed decimal, 9 integer + 2 decimal digits */
    01 #RATES        (N3,4/1:27)  /* array: 27 occurrences of N3,4 */
  END-DEFINE

  /* Main logic here */

END
```

> **The decimal separator in a format specification is a COMMA, never a period.**
> `(P9,2)` and `(N3,4)` are valid; `(P9.2)` and `(N3.4)` **do not compile**.
> This rule applies only to the *declaration* — **literals still use a period**: `MOVE 1.3500 TO #FATOR`.
> In arrays, the range is part of the notation: `(A60/1:10)`, `(N3,4/1:27)`, `(N3,6/1:10,1:12)`.

Key blocks to recognize:

| Block | Purpose |
|-------|---------|
| `DEFINE DATA LOCAL` | Variable declarations scoped to this program |
| `DEFINE DATA PARAMETER` | Input/output variables received from a caller |
| `DEFINE DATA GLOBAL` | Shared among programs in a session (rare, fragile) |
| `INPUT` | Reads from the terminal (online) or sequential file (batch) |
| `DISPLAY` / `WRITE` | Output to a screen or report |
| `MAP` | Screen layout definition (terminal UI) |

## CALLNAT vs PERFORM

- **`CALLNAT 'SUBPROG' parm1 parm2`** — calls an external subprogram (a separate source file). Parameters are passed by reference unless marked `(AD=O)` for output-only.
- **`PERFORM subroutine-name`** — calls an internal subroutine defined with `DEFINE SUBROUTINE ... END-SUBROUTINE` within the same program.

When mapping call chains, `CALLNAT` is the important one — it crosses file boundaries.

## INCLUDE Copycodes

`INCLUDE copycode-name` inserts a shared code fragment at compile time, like a C `#include`. Copycodes typically contain:

- Shared data area definitions (Natural's "struct")
- Common validation routines
- Standard error-handling blocks

When you see `INCLUDE`, find the corresponding copycode to understand the complete data layout.

### Member Extensions

A Natural library is **flat**: there are no subdirectories, and each member is resolved by name, not by path. The extension indicates the type:

| Extension | Type | Called by |
|----------|------|-------------|
| `.NSN` | Program or subprogram | executed by JCL or `CALLNAT` |
| `.NSA` | Parameter Data Area (PDA) | `PARAMETER USING` |
| `.NSL` | Local Data Area (LDA) | `LOCAL USING` |
| `.NSC` | Copycode | `INCLUDE` |
| `.NSM` | Map (3270 screen layout) | `INPUT USING MAP` |
| `.jcl` | Job Control Language | batch scheduler |

`CALLNAT`, `INCLUDE`, `PARAMETER USING`, and `LOCAL USING` **MUST NOT be ignored**: each pulls code or declarations from another file. A program read in isolation is incomplete.

## Adabas FDT (Field Definition Table)

Every Adabas file has an FDT that defines its fields. Think of it as the schema:

| Column | Meaning |
|--------|---------|
| Level | Hierarchical depth (01 = top level, 02+ = children) |
| Name | Two-character short name (AA, AB, AC...) |
| Format | `A` = alpha, `N` = numeric, `P` = packed, `B` = binary, `D` = date, `T` = time |
| Length | Field size in bytes |
| Descriptor | `DE` = searchable index, `MU` = multi-value (array), `PE` = periodic group (repeating group) |

### MU (Multiple-Value) Fields

A field marked `MU` can contain multiple values (like an array). In Natural, it is accessed by index: `FIELD(1)`, `FIELD(2)`, etc. The maximum number of occurrences is defined in the FDT.

**Modern mapping**: `@ElementCollection` in JPA or a JSONB column in PostgreSQL.

### PE (Periodic Groups)

A `PE` group is a repeating group of related fields — like a row in an embedded table. For example, an address history in which each occurrence has a street, city, and date.

**Modern mapping**: an `@OneToMany` relationship with an embedded entity, or a JSONB array.

### Super-Descriptors

A super-descriptor combines multiple fields into a single searchable key (composite index). Notation such as `SU = AA + AB(1-4)` means "concatenate field AA with the first 4 bytes of AB."

**Modern mapping**: `@Index(columnList = "col_a, col_b")` in JPA.

## 1990s Naming Conventions

Legacy Natural codebases use prefix-based names. Common patterns include:

| Prefix Pattern | Typical Meaning |
|---|---|
| `BN-` or `BATCH-` | Batch program or batch-related variable |
| `PG-` or `PROG-` | Main program |
| `PS-` or `SUB-` | Subprogram (called via CALLNAT) |
| `AU-` or `AUT-` | Related to authorization or audit |
| `#` prefix on variables | Local working variable (Natural convention) |
| `+` prefix on variables | Parameter variable passed by the caller |

These are conventions, not rules — verify by reading the code rather than assuming.

## Batch Job Patterns

Batch Natural programs typically follow this structure:

```
READ WORK FILE 1 record
  /* process each record */
  AT END OF DATA
    /* final totals / cleanup */
  END-ENDDATA
END-WORK
```

Control-break reports use:

```
READ logical-file BY descriptor
  AT BREAK OF descriptor
    /* subtotal when descriptor value changes */
  BEFORE BREAK PROCESSING
    /* detail line for each record */
  END-BREAK
END-READ
```

## Packed Decimal Handling

Packed decimal (`P` format) stores digits efficiently: each byte holds two digits, and the final nibble is the sign (C=positive, D=negative). It is common in financial calculations.

When mapping to Java: ALWAYS use `BigDecimal`, NEVER `double` or `float`. Packed fields with the `P9,2` format mean 9 integer digits plus 2 decimal places → `BigDecimal` with `scale(2)`.

**On the mainframe, money is packed (`P`), not `N`.** When reading the corpus, a monetary value declared as `N` is a warning sign — it may be an oversight by the original author or a deliberate divergence between the program and DDM. ALWAYS compare the format in the program with the format of the same field in the `.ddm`: type and size mismatches are a classic source of silent truncation and overflow.

## Reading Strategy

When approaching a legacy program for the first time:

1. **Start with DEFINE DATA** — understand the variables and their types
2. **Find the main READ or FIND** — this reveals which data the program processes
3. **Trace CALLNAT calls** — these are the dependencies
4. **Look for INCLUDE copycodes** — they expand the data definitions
5. **Check AT BREAK / AT END OF DATA** — they reveal reporting or processing logic
6. **Note every ESCAPE or ON ERROR** — these are error-handling paths
7. **Check `IF NO RECORDS FOUND`** — the `FIND ... IF NO RECORDS FOUND ... END-NOREC` block defines what happens when the search returns nothing; this is where silent defaults hide. Remember that view fields have values only **inside** the `FIND`/`READ` block.
8. **Check `FIND ... WITH` against the DDM** — searches are possible only on fields marked as descriptors (`D`, `S`, or `H`) in the DDM listing. A search on a non-descriptor field does not compile.
