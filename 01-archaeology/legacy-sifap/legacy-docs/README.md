---

title: "Legacy Documentation - SIFAP"
description: "Historical technical documents for the original SIFAP system (1997–2012)"
author: "Paula Silva, Americas Software GBB, Microsoft"
date: "2026-04-23"
version: "1.0.0"
status: "approved"
tags: ["legacy", "documentation", "sifap", "architecture", "history"]
---

# Legacy Documentation — SIFAP

> **Path:** [Team Kit](../../../README.md) › [Stage 1](../../README.md) › [SIFAP Legacy](../README.md) › **Legacy Documentation**

**Historical technical documents for the original SIFAP system, covering the period from 1997 to 2012.** Read-only reference material for the software archaeology exercise.

| Field | Value |
|---|---|
| **Target audience** | All pairs during Stage 1 |
| **Prerequisites** | None |
| **Stage** | Stage 1 — Archaeology |
| **Expected outcome** | Understanding of the historical context for cross-checking against the source code |

> [!IMPORTANT]
> The documents in this folder are **read-only reference material**. The business rules documented here must be cross-checked against the Natural programs to verify their current validity—the documentation may be outdated relative to the production code.

---

## Contents

| File | Year | Description |
|---|---|---|
| `ORIGINAL-ARCHITECTURE-1997.md` | 1997 | Technical architecture document for the original project—the planned vision before coding began |
| `ORIGINAL-ARCHITECTURE-1997.docx` | 1997 | Original format (Word) |
| `TECHNICAL-MANUAL-SIFAP-2008.md` | 2008 | Technical operations manual—covers registration modules and part of the calculation and batch modules |
| `TECHNICAL-MANUAL-SIFAP-2008.docx` | 2008 | Original format (Word) |
| `BUSINESS-RULES-2012.md` | 2012 | Partial business-rule survey—discontinued; 47 pages out of an estimated total of 200+ |
| `BUSINESS-RULES-2012.docx` | 2012 | Original format (Word) |

---

## How to Use These Documents

The `.md` files are converted versions that make the documents easier to read in VS Code and on GitHub. The `.docx` files are the original format.

When reading the Natural programs, use these documents to:

1. **Confirm** a rule inferred from the code—if the behavior matches the documentation, classify it as `Confirmed` in the catalog.
2. **Contextualize** architectural decisions that appear arbitrary in the code—technical or regulatory justification is often recorded here.
3. **Identify gaps**—what the documentation describes but the code does not implement, and vice versa.

> [!WARNING]
> The calculation modules (`CALCBENF`, `CALCCORR`, `CALCDSCT`) **have no formal documentation in this folder**. The rules for these programs exist exclusively in the source code. Do not assume that current behavior matches the 2008 documentation.

---

### Continue Reading

| Previous | Next |
|---|---|
| [SIFAP Legacy — overview](../README.md)<br/><sub>System context and complete inventory.</sub> | [Stage 1 — GUIDE](../../GUIDE.md)<br/><sub>Timed 90-minute agenda.</sub> |

<sub>[Back to the kit index](../../../README.md)</sub>
