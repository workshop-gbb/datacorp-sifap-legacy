<!-- markdownlint-disable MD013 MD033 MD041 -->

---
title: "SIFAP Business Rules - Partial Survey"
author: "Ana Cristina Barros - SENARC Business Analyst"
date: "2012-08-14"
version: "1.0.0-DRAFT"
classification: "RESTRICTED"
status: "INCOMPLETE - Survey discontinued"
distribution: "SENARC/CGPB, SUPDE/DESIF, CGTI/MDAS"
revision_history:

- version: "0.1.0"
 date: "2012-06-04"
 author: "Ana Cristina Barros"
 description: "Start of survey - registration module"
- version: "0.5.0"
 date: "2012-07-10"
 author: "Ana Cristina Barros"
 description: "Partial inclusion of calculation and discount modules"
- version: "1.0.0-DRAFT"
 date: "2012-08-14"
 author: "Ana Cristina Barros"
 description: "Latest version - survey discontinued"

---

> [!NOTE]
> This is a reconstructed historical document for the SIFAP 2.0 workshop archaeology exercise. It simulates the partial business-rule survey conducted in 2012 by the SENARC/CGPB team. Period language, personal names, uncertainties, and documented gaps have been intentionally preserved. **This document must not be used as the system's current specification.** Rules marked `[PENDING]`, comments about inconsistencies, and unverified items are part of the exercise—they represent the real knowledge-extraction challenge the team must address during archaeology.

<!-- ====================================================================== -->
<!-- SIFAP BUSINESS RULES - PARTIAL SURVEY -->
<!-- Payment Inspection and Administration System -->
<!-- SENARC - National Secretariat for Citizenship Income -->
<!-- In collaboration with SUPDE/DESIF (the organization) -->
<!-- ====================================================================== -->

# SIFAP BUSINESS RULES - PARTIAL SURVEY

**PAYMENT INSPECTION AND ADMINISTRATION SYSTEM**

---

|                        |                              |
| ---------------------- | ---------------------------- |
| **Document:** | RN-SIFAP-2012-partial |
| **Classification:** | RESTRICTED |
| **Issue date:** | 14/08/2012 |
| **Status:** | DRAFT - INCOMPLETE |
| **Responsible:** | Ana Cristina Barros - SENARC |
| **Technical validation:** | Pending |

---

> **DOCUMENT IN PROGRESS**
>
> Survey started in June/2012, interrupted in August/2012 due to lack of availability of the technical team. The retirement of Mr. Roberto Carlos Meirelles (senior analyst, retired since 2010) and the transfer of Ms. Fernanda Oliveira (business analyst, retired in 2012) significantly compromised the continuity of this work.
>
> The rules documented below represent a **partial survey**, based on:
>
> - Interviews with Marcos Antônio Ferreira (senior Natural programmer);
> - Partial analysis of the source code of the programs CADBENEF, CALCBENF and VALELEG;
> - Existing documentation (Technical Manual SIFAP v2.3.1, 2008);
> - Institutional knowledge of the SENARC/CGPB team.
>
> **This document has NOT been validated by the organization's technical team and may contain inaccuracies.**

---

## 1. Beneficiary Registration

### 1.1. Inclusion Rules

**RN-001** - Every beneficiary must have a valid CPF (validation by check digit - subprogram VALCPF) and active NIS/NIT (validation via subprogram VALNISN).

**RN-002** - It is not permitted to include a beneficiary with CPF already in the registry in active status (BN-CD-SIT = 'A'). Logically excluded beneficiaries (BN-CD-SIT = 'E') can be re-included upon new registration.

**RN-003** - The beneficiary must be linked to at least one active social program (field BN-CD-PROG referencing valid registration in DDM PROGRAMA-SOCIAL with PS-IN-ATIVO = 'S').

**RN-004** - The maximum number of dependents per beneficiary is **3** (field BN-QT-DEPEND, values ​​from 0 to 3). For programs that require a higher number, request authorization from the CGPB via form FR-SIFAP-012.

<!-- NOTE: Check with Marcos Antônio—there is evidence in the code that the
 limit was changed to 5 during a recent maintenance update, but we could
 not confirm it. The Technical Manual v2.3 (2008) also records 3. -->

**RN-005** - The region field (BN-CD-REGIAO) must correspond to a valid region according to the SIFAP internal table (values ​​01 to 27, corresponding to the Brazilian states and Federal District). The value 99 is reserved for internal use.

<!-- NOTE: The value 99 in the BN-CD-REGIAO field appears in several records
 in the production base, but we were unable to identify its purpose.
 Marcos Antônio said that "it is Roberto's bypass" but could not provide
 details. Review the CADBENEF code. -->

**RN-006** - Date of birth (BN-DT-NASC) is a mandatory field. Beneficiaries under the age of 16 on the date of inclusion are not accepted, except as dependents.

**RN-007** - Banking details (bank, branch, account) are mandatory for active beneficiaries. SIFAP validates the bank code against an internal table (last update: 2011).

### 1.2. Change Rules

**RN-008** - [PENDING] - Rules for changing bank details. It was not possible to access the responsible code during the survey period. Check with Mr. Roberto Carlos (retired since 2010).

**RN-009** - Changing a beneficiary's CPF requires level 2 authorization (SUPERVISOR profile in session GDA). The old CPF is maintained in the BN-NR-CPF-ANT field for audit purposes.

**RN-010** - Every registration change generates automatic audit records via subprogram LOGAUDIT (fields: user, date/time, changed field, previous value, new value).

### 1.3. Exclusion Rules

**RN-011** - Beneficiary exclusion is always logical (BN-CD-SIT changed from 'A' to 'E'). There is no physical deletion of records in DDM BENEFICIARIO.

**RN-012** - Deletion of beneficiaries with pending payments (PG-CD-STATUS = 'P') is blocked by the system. The operator must wait for settlement or cancel payments before deletion.

---

## 2. Calculation of Benefits

### 2.1. Basic Calculation Formula

**RN-013** - The monthly benefit amount is calculated using the following formula:

```
VALOR-BENEFICIO = VALOR-BASE(program, bracket) + (ACRESCIMO-DEPEND * QT-DEPEND)
```

Where:

- `VALOR-BASE` is obtained from DDM PROGRAMA-SOCIAL according to the beneficiary's declared income range;
- `ACRESCIMO-DEPEND` is the additional amount per dependent, defined by program;
- `QT-DEPEND` is the number of active dependents linked to the primary beneficiary.

**RN-014** - The benefit amount is always rounded down to cents (truncation, not mathematical rounding). Example: R$ 125,567 → R$ 125,56.

<!-- NOTE: The above formula is the BASIC formula. Marcos Antônio mentioned that
 there are "at least 3 more variations" in the CALCBENF code, including
 a special calculation for December (13th benefit / year-end bonus)
 and a multiplier called "FATOR-K" that he could not explain. It was
 not possible to validate this with the team.

 The proportional calculation rule for benefits starting mid-month
 (pro rata) is also undocumented. -->

### 2.2. Value Ranges

**RN-017** - The value ranges are parameterized in DDM PROGRAMA-SOCIAL, using PE (periodic group) fields indexed by fiscal year. Each social program can have up to 10 defined value ranges.

**RN-018** - The range applicable to the beneficiary is determined by the declared per capita family income (field BN-VL-RENDA-PC). The band assignment follows ascending order of income, with the first band whose upper limit is greater than or equal to the declared income being applied.

### 2.3. Readjustments and Corrections

**RN-019** - The annual benefit adjustment is applied in January of each year, based on an index defined by presidential decree. The index is registered in the internal table of subprogram CALCIDX.

**RN-020** - The adjustment is applied to VALOR-BASE, not to the total benefit amount (including the dependent increment). Review the code—this could not be validated with the team.

---

## 3. Discounts and Deductions

> **Note:** This module was implemented in 2015 (program CALCDSCT) and was not included in system version 2.3.1 covered by the 2008 Technical Manual. The rules below were gathered from an interview with Marcos Antônio Ferreira, who implemented the module.

**RN-021** - The total discounts applicable to a benefit cannot exceed **30% of the gross value**. Discounts that exceed this limit are rejected, and the benefit is processed without discounts, generating an audit.

<!-- NOTE: Marcos Antônio mentioned that there is an exception for withholdings
 ordered by a court (garnishment or freezing orders), which may
 exceed the 30% limit. This could not be confirmed in the code
 because access to the CALCDSCT program is restricted and the analysis was not
 completed during the survey. -->

**RN-022** - The types of discount provided are:

| Code | Discount Type | Note |
| ------ | -------------------------------- | -------------------------------------------- |
| 01 | Voluntary Consignment | Authorized payroll loan |
| 02 | Income tax withheld at source | According to the current Federal Revenue table |
| 03 | Social security contribution | When applicable |
| 04 | Reimbursement to the treasury | Improper payment identified in audit |
| 05 | [TO BE COMPLETED] | Marcos Antônio mentioned "2 or 3 more types" |

**RN-023** - The order in which discounts are applied follows the numerical priority of the code (01 first, then 02, etc.). When the 30% limit is reached, lower priority discounts are discarded.

---

## 4. Eligibility

### 4.1. Basic Eligibility Rules

**RN-015** - [PENDING] - Detailed eligibility rules by program. The SENARC/CGPB team reported that rules vary significantly between programs and that complete documentation would require interviews with each program's managers. Survey not carried out due to lack of agenda.

**RN-016** - [PENDING] - Crossing rules with CadÚnico. Integration with CadÚnico was implemented on an emergency basis in 2006 and the responsible program is not included in the official SIFAP inventory. The source code could not be located during the search.

### 4.2. Documented Rules (partial)

The following eligibility rules have been identified in program code VALELEG:

- Beneficiary must have active registration status (BN-CD-SIT = 'A');
- Beneficiary must have valid and complete bank details;
- The declared per capita family income must be within the ranges defined for the program;
- The beneficiary cannot be enrolled in more than 2 social programs simultaneously (field BN-QT-PROG, maximum = 2);
- The date of the last registration update cannot be more than 24 months ago (field BN-DT-ULT-ATUAL);
- The beneficiary cannot have an unresolved audit occurrence of type 'B' (blocking) in DDM AUDITORIA.

> **Note:** The rules above were extracted by reading the VALELEG source code and may not represent all of the checks performed. The program has approximately 1,200 lines of code with complex conditional logic.

<!-- NOTE: The region 99 bypass rule is not documented.
 During the analysis of VALELEG, a code snippet was identified
 which bypasses all eligibility validation when BN-CD-REGIAO = 99.
 Marcos Antônio was unable to explain the origin of this rule. It is suspected
 that is an implemented testing mechanism or administrative bypass
 by Mr. Roberto Carlos. Needs investigation. -->

---

## 5. Payment Batch

### 5.1. Monthly Processing

Monthly batch processing (program BATCHPGT) follows the following rules:

- Processing starts on the 1st business day of each month, at 10:00 pm;
- All active beneficiaries (BN-CD-SIT = 'A') are processed;
- Processing occurs in **standard ordering** (according to file descriptor Adabas);
- For each beneficiary, the benefit value is recalculated by invoking CALCBENF;
- After calculation, discounts are applied by invoking CALCDSCT (from version 4.0);
- The payment record is recorded in the DDM PAGAMENTO with status 'P' (pending);
- At the end of processing, the delivery file CNAB 240 is generated.

<!-- NOTE: The "default ordering" mentioned above is, in practice, the
 alphabetically by the name of the beneficiary (field BN-NM-BENEF), which is the
 main descriptor of the file Adabas FNR 150. This ordering is a
 artifact of the original 1997 modeling and has no functional significance.
 However, changing the processing order could cause discrepancies
 in the control totalizers, as the program uses accumulators
 partial alphabetical range. -->

### 5.2. Error Handling

- Calculation errors for an individual beneficiary do not interrupt processing;
- Beneficiaries with errors are marked with status 'E' (error) in DDM PAGAMENTO;
- An error report is generated at the end of processing;
- If the number of errors exceeds the parameter MAX-ERROS (default: 100), processing is stopped with ABEND U4038;
- [TO BE COMPLETED] - Document procedure for reprocessing beneficiaries with errors.

---

## 6. Rules Pending Survey

The following areas of business rules were **not documented** in this survey:

| Area | Reason | Estimated Priority |
| ------------------------------------------- | ------------------------------------------------------------ | ------------------- |
| Calculation of the 13th benefit (Christmas bonus) | Unable to access specific routine on CALCBENF | High |
| K factor (calculation multiplier) | Marcos Antônio was unable to explain; need code analysis | High |
| Financial Reconciliation Rules (BATCHCON) | Patrícia Helena Moura (responsible) transferred to DEGED | Average |
| Integration with CadÚnico | Program not cataloged; source code not found | Average |
| Audit Rules (RELAUDIT) | Module not covered by the initial scope of this survey | Average |
| Proportional calculation (pro rata) | Mentioned by Marcos Antônio, not detailed | High |
| Judicial exception to the discount limit | Mentioned by Marcos Antônio, not confirmed in the code | High |
| Region Eligibility Bypass 99 | Identified in the code, with no known explanation | High |
| Dependent separation rules | Undocumented | Low |
| Rollback and reprocessing procedures | Referred to Manual ITSM-SIFAP vol. 3 (never completed) | High |

---

## 7. Rules Matrix - Summary

| ID | Module | Rule (summary) | Status | Note |
| ------ | ------------- | ------------------------------------------- | ------------ | ---------------------------------------------- |
| RN-001 | Registration | CPF and NIS mandatory and valid | Documented | - |
| RN-002 | Registration | CPF single for active beneficiary | Documented | - |
| RN-003 | Registration | Mandatory link with social program | Documented | - |
| RN-004 | Registration | Maximum 3 dependents | Documented | **Possible outdated - check code** |
| RN-005 | Registration | Valid region (01-27) + 99 reserved | Documented | Meaning of 99 unknown |
| RN-006 | Registration | Minimum age 16 years | Documented | - |
| RN-007 | Registration | Mandatory bank details | Documented | Outdated bank table (2011) |
| RN-008 | Registration | Changing bank details | **PENDING** | Not raised |
| RN-009 | Registration | Change of CPF - SUPERVISOR level | Documented | - |
| RN-010 | Registration | Automatic auditing of changes | Documented | - |
| RN-011 | Registration | Always logical exclusion | Documented | - |
| RN-012 | Registration | Deletion block pending payment | Documented | - |
| RN-013 | Calculation | Basic benefit formula | Documented | **Partial formula - variations missing** |
| RN-014 | Calculation | Rounding by truncation | Documented | - |
| RN-015 | Eligibility | Detailed rules per program | **PENDING** | Lack of SENARC agenda |
| RN-016 | Eligibility | Crossing with CadÚnico | **PENDING** | Program not found |
| RN-017 | Calculation | Parameterized value ranges | Documented | - |
| RN-018 | Calculation | Band assignment by income | Documented | - |
| RN-019 | Calculation | Annual adjustment in January | Documented | - |
| RN-020 | Calculation | Adjustment on base value | Documented | **Not validated with technical team** |
| RN-021 | Discounts | Limit of 30% of the gross value | Documented | **Undocumented judicial exception** |
| RN-022 | Discounts | Types of discount | Documented | Incomplete list |
| RN-023 | Discounts | Discount priority order | Documented | - |

---

## 8. Final Considerations

This survey was stopped prematurely and represents, at best, **about 25% of the SIFAP business rules**. The most critical and complex rules - calculation of the 13th benefit, K factor, judicial exceptions, eligibility bypass - remain **undocumented** and exist only in the Natural source code.

The continuity of this work depends on:

1. Availability of Marcos Antônio Ferreira (last analyst with full knowledge of the system) for knowledge transfer sessions;
2. Access to the source code of the CALCBENF, CALCDSCT and VALELEG programs in an approval environment;
3. Support from CGPB to validate the rules with social program managers;
4. Formal prioritization by CGTI/MDAS, as this survey is not included in the current work plan.

**Recommendation:** If this survey is not resumed in the short term, it is suggested that at least the rules marked as "High priority" in section 6 be investigated directly in the source code, before Mr. Marcos Antônio Ferreira is transferred or retires.

<!-- This recommendation was not met. Marcos Antônio was transferred
 for SUPDE/DESIN in 2017. -->

---

**Elaboration:** Ana Cristina Barros - Business Analyst - SENARC/CGPB

**Technical collaboration:** Marcos Antônio Ferreira - Senior Natural Programmer - SUPDE/DESIF

**Validation:** Pending

**Approval:** Pending

---

**Document internal to the organization/SENARC - Classification: RESTRICTED - Reproduction prohibited**

---

[Back to legacy scenario](../README.md)
