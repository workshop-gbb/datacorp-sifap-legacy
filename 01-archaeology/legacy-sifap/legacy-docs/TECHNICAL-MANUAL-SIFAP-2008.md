---
title: "SIFAP Technical Manual - Payment Inspection and Administration System"
author: "Fernanda Lucia de Oliveira - SUPDE/DESIF"
date: "2008-11-20"
version: "2.3.1"
classification: "RESTRICTED"
distribution: "SUPDE/DESIF, CGTI/MDAS, SENARC/CGPB"
revision_history:

- version: "1.0.0"
 date: "2006-03-10"
 author: "Fernanda Lucia de Oliveira"
 description: "Initial version - registration module"
- version: "2.0.0"
 date: "2007-08-22"
 author: "Fernanda Lucia de Oliveira"
 description: "Inclusion of calculation and batch modules"
- version: "2.3.0"
 date: "2008-09-15"
 author: "Fernanda Lucia de Oliveira"
 description: "General review, inclusion of audit module"
- version: "2.3.1"
 date: "2008-11-20"
 author: "Fernanda Lucia de Oliveira"
 description: "Textual corrections and inclusion of updated contacts"
approval:
- name: "Roberto Carlos Meirelles"
 role: "Senior Systems Analyst - SUPDE/DESIF"
 date: "2008-11-25"
- name: "Maria Helena Costa"
 role: "DESIF Coordinator"
 date: "2008-12-02"

---

> [!NOTE]
> This is a reconstructed historical document for the SIFAP 2.0 workshop archaeology exercise. It simulates Technical Manual version 2.3.1 (2008), as it would have been produced by the SUPDE/DESIF team. Period language and the names of people, units, and procedures have been intentionally preserved. **This document must not be used as the system's current specification.** Sections marked `[TO BE COMPLETED]` and internal comments about outdated information are part of the exercise—they represent real documentation gaps the team must investigate.

<!-- ====================================================================== -->
<!-- SIFAP TECHNICAL MANUAL - VERSION 2.3 -->
<!-- Payment Inspection and Administration System -->
<!-- the organization - the federal data processing organization -->
<!-- Development Superintendency - SUPDE / DESIF -->
<!-- ====================================================================== -->

# SIFAP TECHNICAL MANUAL - VERSION 2.3

**PAYMENT INSPECTION AND ADMINISTRATION SYSTEM**

---

|                                |                                            |
| ------------------------------ | ------------------------------------------ |
| **Document:** | MT-SIFAP-2008-v2.3.1 |
| **Classification:** | RESTRICTED |
| **System version covered:** | 2.3.1 |
| **Issue date:** | 20/11/2008 |
| **Responsible:** | Fernanda Lucia de Oliveira - SUPDE/DESIF |
| **Technical approval:** | Roberto Carlos Meirelles - Senior Analyst |
| **Management approval:** | Maria Helena Costa - Coord. DESIF |

---

> **WARNING:** This manual refers to version 2.3.1 of the SIFAP. For information on subsequent versions, consult the addenda published by SUPDE/DESIF or contact the responsible technical team.

---

## 1. Introduction

### 1.1. Purpose of the Document

This manual aims to document the technical aspects of **SIFAP - Payment Inspection and Administration System**, in order to support the system's maintenance, operation and support activities.

This document is intended to:

- SUPDE/DESIF systems analysts allocated to the SIFAP project;
- Organization mainframe operation team - Brasília Regional;
- SENARC/CGPB business analysts, for technical reference purposes;
- Adabas DBA team responsible for the production environment.

### 1.2. Scope

<!-- NOTE: This section has not been updated since 2008 -->

This manual covers the following aspects of SIFAP version 2.3.1:

- General system architecture;
- Description of modules and programs;
- Monthly processing flow;
- Contingency procedures;
- Technical team contacts.

**Not within the scope of this document:**

- Detailed business rules (see Business Rules Manual - being prepared by SENARC);
- Adabas backup and recovery procedures (see DBA Operation Manual - Cláudia Regina dos Santos, 2007);
- Operational user manual (see Manual ITSM-SIFAP vol. 2).

### 1.3. Related Documents

| Code | Title | Author | Status |
| ----------------- | ----------------------------------- | -------------- | ------------- |
| MT-SIFAP-2008 | This document | F. L. Oliveira | Current |
| MO-SIFAP-DBA-2007 | DBA Operation Manual Adabas | C.R. Santos | Current |
| MU-SIFAP-2006 | User Manual - Registration Module | F. L. Oliveira | Current |
| ITSM-SIFAP-vol1 | ITSM Procedures - Incidents | A. C. Ribeiro | Current |
| ITSM-SIFAP-vol2 | ITSM Procedures - Operation | A. C. Ribeiro | Current |
| ITSM-SIFAP-vol3 | ITSM Procedures - Changes | [TO BE COMPLETED] | In preparation |
| RN-SIFAP | Business Rules Manual | SENARC/CGPB | Not started |

> **Note:** The ITSM-SIFAP Manual vol. 3 (Change Procedures) has been in the preparation phase since June 2008. Expected completion: March/2009.

---

## 2. System Architecture

<!-- NOTE: This section has not been updated since 2008 -->

### 2.1. Technological Platform

The SIFAP is developed and run in the organization's mainframe environment, using the following platform:

| Component | Version | Observations |
| -------------- | -------- | -------------------------------------------------------------------------------- |
| **Natural** | 6.3.12 | Development language - updated in 2005 (migration from v4.2) |
| **Adabas** | 7.4.3 | DBMS - updated in 2005 (migration from v6.1) |
| **Com\*plete** | 6.3.1 | Teleprocessing monitor for 3270 screens |
| **JES2** | z/OS 1.8 | Batch job entry subsystem |
| **CICS** | TS 3.1 | Used only for integration with query transaction CPF (Federal Revenue) |
| **z/OS** | 1.8 | Mainframe Operating System |

### 2.2. Natural Library Structure

The SIFAP objects are organized in the Natural **SIFAP** library, as follows:

```
SIFAP Library
├── Programs (executable programs)
├── Subprograms (routines called by CALLNAT)
├── Copycodes (code blocks included via INCLUDE)
├── Maps (3270 screens - input/output maps)
├── DDMs (Data Definition Modules - access to Adabas)
├── LDAs (Local Data Areas)
└── GDAs (Global Data Areas)
```

### 2.3. Data Model

The SIFAP uses **3 main DDMs** in the Adabas:

| DDM | File (FNR) | Description |
| --------------- | ------------- | -------------------------------- |
| BENEFICIARY | FNR 150 | Beneficiary registration |
| SOCIAL-PROGRAM | FNR 151 | Parameters of social programs |
| PAYMENT | FNR 152 | Payment records |

<!-- NOTE: The DDM AUDIT (FNR 153), created in 2005 during the migration to
 Natural 6.3, not included in this section as it was added after writing
 beginning of this chapter. Check with Roberto Carlos for update. -->

> **Technical note:** The detailed description of the fields of each DDM can be found in the DBA Operation Manual (MO-SIFAP-DBA-2007). The FDTs (Field Definition Tables) are under the responsibility of DBA Cláudia Regina dos Santos.

### 2.4. Component Diagram

```mermaid
%%{init: {'theme':'neutral','themeVariables':{'fontFamily':'ui-sans-serif, system-ui, sans-serif','primaryColor':'#F5F5F5','primaryTextColor':'#171717','primaryBorderColor':'#171717','lineColor':'#525252','secondaryColor':'#FFFFFF','tertiaryColor':'#FAFAFA','background':'#FFFFFF'}}}%%
TB flowchart
    classDef step fill:#F5F5F5,stroke:#171717,color:#171717
    classDef artifact fill:#FAFAFA,stroke:#A3A3A3,color:#404040
    classDef external fill:#FFFFFF,stroke:#525252,color:#171717

    subgraph MAIN["Mainframe environment — the organization"]
        NAT["Natural 6.3.12<br/>8 online programs"]:::step
        ADA["Adabas 7.4.3<br/>3 DDMs"]:::step
        JES["JES2 / z/OS 1.8<br/>Jobs Batch"]:::step
        NAT <--> ADA
        JES --> ADA

        COMPLETE["Comp*plete<br/>Telas 3270"]:::step
        BATCH["BATCHPGT<br/>BATCHREL<br/>BATCHCON"]:::step
        NAT --> COMPLETE
        JES --> BATCH
    end

    TERM["3270 Terminals<br/>Operators"]:::external
    EXTFILES["External Files<br/>CNAB 240 / TXT<br/>BB / SIAFI"]:::external

    COMPLETE --> END
    BATCH --> EXTFILES
```

<!-- NOTE: This diagram does not reflect programs added in 2005
 (RELAUDIT, CALCCORR) nor the DDM AUDIT. Request update
 to the responsible analyst. -->

---

## 3. System Modules

<!-- NOTE: This section has not been updated since 2008 -->

### 3.1. Program Overview

The SIFAP is made up of **12 main programs**, organized into the following modules:

| No | Program | Module | Type | Description |
| --- | --------- | --------- | ------------ | --------------------------------------------------------- |
| 01 | CADBENEF | Registration | Online | Beneficiary registration - inclusion, alteration, exclusion |
| 02 | CADDEPEND | Registration | Online | Registration of dependents of the beneficiary |
| 03 | CADPROG | Registration | Online | Registration of social programs and parameters |
| 04 | CALCBENF | Calculation | Batch/Online | Calculation of benefit value by band/program |
| 05 | CALCCORR | Calculation | Batch | Calculation of annual corrections and adjustments |
| 06 | VALBENEF | Validation | Online | Registration validation (CPF, NIS, duplicity) |
| 07 | VALELEG | Validation | Online | Validation of eligibility per program rules |
| 08 | VALDOCS | Validation | Online | Validation of supporting documentation |
| 09 | BATCHPGT | Batch | Batch | Monthly Payroll Processing |
| 10 | BATCHREL | Batch | Batch | Batch report generation |
| 11 | BATCHCON | Batch | Batch | Financial reconciliation with SIAFI |
| 12 | CONSBENF | Consultation | Online | Beneficiary consultation - screen with filters |

<!-- NOTE: This list does not include programs CALCDSCT, RELPGT and RELAUDIT,
 which were added to the system after the preparation of this manual.
 CALCDSCT was included in version 4.0 (2015).
 RELPGT and RELAUDIT were restructured/included in version 3.0 (2005).
 This manual only covers system version 2.3.1. -->

### 3.2. Registration Module

#### 3.2.1. CADBENEF - Beneficiary Registration

**Description:** Online program for maintaining beneficiary registration. Allows logical inclusion, alteration and deletion of records in DDM BENEFIC, the Beneficiary file.

**Transaction:** SF01 (inclusion), SF02 (change), SF03 (deletion)

**Features:**

- Inclusion of a new beneficiary with validation of CPF (called subprogram VALCPF);
- Change of registration data (address, bank details, status);
- Logical deletion (field BN-CD-SIT changed to 'E');
- Audit log for all operations (called subprogram LOGAUDIT);
- Link to the social program (key: BN-CD-PROG → PS-CD-PROG).

**Observations:**

- The BN-QT-DEPEND field (number of dependents) accepts values ​​from 0 to 3.
- [TO BE COMPLETED] - Detail validation rules for changing bank details.
- [TO BE COMPLETED] - Document beneficiary treatment with multiple programs.

<!-- NOTE: The dependent limit was changed to 5 sometime between
 2010 and 2015, as required by SENARC. This change is not reflected
 in this document. Check in the source code of CADBENEF. -->

#### 3.2.2. CADDEPEND - Dependent Registration

**Description:** Online program for registering dependents linked to the titular beneficiary.

**Transaction:** SF04

**Features:**

- Inclusion of dependent with validation of CPF and date of birth;
- Link to the titular beneficiary (key: BN-NR-CPF);
- Verification of dependent limit (maximum: 3 per holder);
- Control of type of dependent (spouse, child, other).

**Observations:**

- Validation of the minimum/maximum age of dependents follows the rules of the social program. See code CADBENEF for details.
- [TO BE COMPLETED] - Document dependent separation rules.

#### 3.2.3. CADPROG - Social Programs Registration

**Description:** Online program for maintaining the parameters of social programs.

**Transaction:** SF06

**Features:**

- Inclusion and alteration of social programs;
- Parameterization of value ranges (fields MU in DDM SOCPROG);
- Definition of eligibility rules per program;
- Validity control (start/end date).

**Observations:**

- Restricted access to the ADMIN profile (check via session GDA).
- [TO BE COMPLETED] - Detail the procedure for including a new social program.

### 3.3. Calculation Module

#### 3.3.1. CALCBENF - Benefits Calculation

**Description:** Program for calculating the value of the benefit to be paid to the beneficiary, based on the ranges and rules defined in DDM SOCPROG.

**Features:**

- Calculation of the base value according to the program range;
- Application of increases per dependent;
- Proportional calculation for benefits starting in the middle of the month;
- [TO BE COMPLETED] - Rules for calculating the 13th benefit (Christmas bonus).

**Observations:**

- This program is invoked both online (simulation) and batch (monthly processing).
- The calculation logic is entirely in the Natural code, without external parameterization.
- Consult with Mr. Roberto Carlos to detail the formula for calculating the additional band.

#### 3.3.2. CALCCORR - Corrections Calculation

**Description:** Batch program for applying correction indices and adjustments to benefit values.

**Features:**

- Reading of internal index table (subprogram CALCIDX);
- Application of index on base value;
- Generation of readjustment log for auditing.

**Observations:**

- Executed annually in January or when there is an adjustment decree.
- [TO BE COMPLETED] - Document index table format and update procedure.

### 3.4. Validation Module

[TO BE COMPLETED] - Section pending details. The VALBENEF, VALELEG and VALDOCS programs have self-explanatory features. For details, consult the source code or contact Roberto Carlos Meirelles.

### 3.5. Batch Module

#### 3.5.1. BATCHPGT - Payment Processing

**Description:** SIFAP main batch program. Responsible for monthly payroll processing.

**Scheduling:** 1st business day of the month, 10:00 pm (Brasília time)

**Execution flow:**

1. Sequential reading of DDM BENEFIC, the Beneficiary file (active registers, BN-CD-SIT = 'A');
2. For each beneficiary, invoke CALCBENF to obtain the benefit value;
3. Record recording on DDM PAYMENT with status 'P' (pending);
4. Generation of the remittance file CNAB 240 for Banco do Brasil;
5. Totalization and recording of processing logs.

**JCL Parameters:**

```
//SIFAPPGT JOB (SIFAP,BATCH),'FOLHA MENSAL',
// CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1)
//STEP01 EXEC NATBATCH,PROGRAM=BATCHPGT
//SYSIN DD *
 MES-REF=MMAAAA
 TIPO-PROC=NORMAL
 MAX-ERROS=100
/*
```

**Observations:**

- Average execution time: 2h45min (reference: Oct/2008, ~3,200,000 records).
- Processing is **sequential in alphabetical order** of the beneficiary's name (field BN-NM-BENEF). This order is determined by the Adabas descriptor configured on the FNR 150.
- In case of ABEND, see restart procedure in section 5 of this manual.

<!-- NOTE: Runtime has increased considerably since 2008 due to
 base growth. In 2016, a timeout incident was reported with
 processing 4.1 million records. -->

#### 3.5.2. BATCHREL - Batch Reports

**Description:** Generation of post-processing totalizing reports.

**Observations:**

- Executed upon successful completion of BATCHPGT.
- Generates reports in text format (132 columns) for printer.
- [TO BE COMPLETED] - List reports generated and recipients.

#### 3.5.3. BATCHCON - Financial Reconciliation

**Description:** Conciliation program between payments processed by SIFAP and confirmations received from SIAFI and paying banks.

**Observations:**

- Executed upon receipt of return files (D+2 after shipment).
- [TO BE COMPLETED] - Document format of return files and reconciliation rules.
- For operating procedures, see Manual ITSM-SIFAP vol. 3.

---

## 4. Monthly Processing Flow

### 4.1. Standard Calendar

The monthly processing cycle for the SIFAP follows the following calendar:

| Business Day | Activity | Responsible | System/Program |
| --------- | ------------------------------------------------------ | ------------------------- | -------------------------- |
| D-5 | Update of parameter tables (ranges, indices) | SENARC/CGPB | CADPROG (online) |
| D-3 | Closing registration - blocking changes | Operation the organization | Manual procedure |
| D-2 | Batch eligibility validation | Operation the organization | VALELEG (batch) |
| D-1 | Totalizers conference - preview report | CGPB | BATCHREL (previous mode) |
| D (1st DU) | **Payroll processing** | Operation the organization | BATCHPGT |
| D+1 | Sending file CNAB 240 to Banco do Brasil | Operation the organization | Manual Transfer (FTP) |
| D+2 | Sending bank orders to SIAFI | Operation the organization | Procedure SIAFI |
| D+3 | Receipt of bank return file | Operation the organization | Reception FTP |
| D+4 | Financial reconciliation | Operation the organization | BATCHCON |
| D+5 | Generation of final reports | CGPB | BATCHREL |
| D+10 | Closing the cycle - archiving | CGPB | Manual procedure |

### 4.2. Flow Diagram

```mermaid
%%{init: {'theme':'neutral','themeVariables':{'fontFamily':'ui-sans-serif, system-ui, sans-serif','primaryColor':'#F5F5F5','primaryTextColor':'#171717','primaryBorderColor':'#171717','lineColor':'#525252','secondaryColor':'#FFFFFF','tertiaryColor':'#FAFAFA','background':'#FFFFFF'}}}%%
TB flowchart
    classDef step fill:#F5F5F5,stroke:#171717,color:#171717
    classDef artifact fill:#FAFAFA,stroke:#A3A3A3,color:#404040

    CADPROG["CADPROG<br/>(D-5)<br/>Parameter update"]:::step
    VALELEG_PRE["VALELEG<br/>(D-2)<br/>Eligibility Validation"]:::step
    BATCHREL_PRE["BATCHREL<br/>(D-1)<br/>Preview"]:::step
    BATCHPGT["BATCHPGT<br/>(D = 1st DU)<br/>Payroll"]:::step
    CNAB["File CNAB<br/>BB"]:::artifact
    DDM_PAGTO["DDM PAYMENT<br/>(Adabas)"]:::artifact
    LOG["Processing Log"]:::artifact
    RETURN["Bank Return<br/>(D+3)"]:::artifact
    BATCHCON["BATCHCON<br/>(D+4)<br/>Reconciliation"]:::step
    BATCHREL_POS["BATCHREL<br/>(D+5)<br/>Final reports"]:::step

    CADPROG --> VALELEG_PRE --> BATCHREL_PRE --> BATCHPGT
    BATCHPGT --> CNAB
    BATCHPGT --> DDM_PAGTO
    BATCHPGT --> LOG
    CNAB --> RETURN
    RETURN --> BATCHCON
    BATCHCON --> BATCHREL_POS
```

### 4.3. Exception Handling

<!-- NOTE: This section has not been updated since 2008 -->

| Situation | Procedure | Responsible |
| ------------------------------ | ------------------------------------------------------------------------------ | ------------------------- |
| ABEND on BATCHPGT | Restart from last checkpoint (see section 5.2) | Operation the organization |
| File CNAB rejected by BB | Manual correction and resubmission. Contact Antônio Carlos Ribeiro.                    | Operation the organization |
| Divergence in conciliation | Manual analysis by CGPB. Register incident in ITSM.                         | CGPB + the organization |
| Delay in bank returns | Wait until D+5. If not received, contact BB via dedicated channel.             | Operation the organization |
| Reprocessing Request | CGPB approval. Rollback procedure according to Manual ITSM-SIFAP vol. 3. | CGPB |

> **IMPORTANT:** For detailed rollback and reprocessing procedures, see **Manual ITSM-SIFAP vol. 3** (in preparation - forecast: March/2009).

---

## 5. Contingency Procedures

### 5.1. Contingency Plan - Overview

<!-- NOTE: This section has not been updated since 2008 -->

The SIFAP contingency plan covers the following scenarios:

| Scenario | Level | Procedure |
| ------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------ |
| Mainframe unavailability (< 4h) | 1 | Wait for recovery. Reschedule batch if necessary.                                              |
| Mainframe unavailability (> 4h) | 2 | Trigger processing at the contingency site (the organization-RSA). Contact Antônio Carlos Ribeiro. |
| Data corruption Adabas | 3 | Recovery via ADASAV (last healthy backup). Contact Cláudia Regina dos Santos (DBA).                 |
| Integration failure SIAFI | 2 | Manual processing of bank orders by CGPB. Procedure described in Manual ITSM-SIFAP vol. 2. |
| Transmission failure CNAB | 1 | Manual retransmission via alternate channel (SFTP). Contact operation BB.                               |

### 5.2. Restart Procedure - BATCHPGT

In case of ABEND while running BATCHPGT, follow the steps below:

1. Check the ABEND code in the JES2 (JESMSGLG) log;
2. Identify the last recorded checkpoint (field CKPT-NR in SYSOUT);
3. Correct the error condition according to the table of known ABENDs (see section 5.3);
4. Restart the job with parameter `RESTART=CKPT-nnn` (where nnn = number of the last checkpoint);
5. Monitor execution until normal completion (COND CODE = 0000);
6. Check final totals against previous report (D-1).

### 5.3. Table of Known ABENDs

| Code | Description | Probable Cause | Action |
| ----------- | ------------------------ | ------------------------------------------- | ---------------------------------------------------------------- |
| S0C7 | Data exception | Numeric field with invalid value in Adabas | Identify corrupt registry via ADAORD. Correct or delete. |
| S878 | Virtual storage exceeded | Processing volume above forecast | Increase REGION on JCL. Contact operation.                       |
| S0C4 | Protection exception | Addressing error in subprogram | Contact Roberto Carlos Meirelles for analysis.                  |
| U4038 | Natural runtime error | Overflow error in calculation | Check values ​​in DDM SOCPROG (ranges).                      |
| ADA-RSP 148 | Adabas timeout | Response time exceeded | Check containment on Adabas. Contact DBA.                     |

### 5.4. Rollback Procedure

[TO BE COMPLETED] - Complete rollback procedure will be documented in Manual ITSM-SIFAP vol. 3. In the meantime, contact Roberto Carlos Meirelles for guidance.

---

## 6. Technical Team Contacts

<!-- NOTE: This section has not been updated since 2008 -->
<!-- Several of the contacts below may no longer be valid. -->
<!-- Check current server capacity in the HR system/organization. -->

### 6.1. Organization Team - SUPDE/DESIF

| Name | Function | Extension | Email | Note |
| -------------------------- | -------------------------------- | ----- | ------------------------------- | ----------------------------------------- |
| Roberto Carlos Meirelles | Senior Analyst / Coord. Technical | 3411 | <roberto.meirelles@client.gov.br> | Architecture and technical decisions |
| Fernanda Lucia de Oliveira | Business Analyst | 3415 | <fernanda.oliveira@client.gov.br> | Documentation and business rules |
| Marcos Antônio Ferreira | Senior Natural Programmer | 3418 | <marcos.ferreira@client.gov.br> | Code maintenance - calculation modules |
| Cláudia Regina dos Santos | DBA Adabas | 3422 | <claudia.santos@client.gov.br> | Database Administration |
| José Aparecido Lima | Natural Programmer | - | - | Retired since 2005 |
| Patrícia Helena Moura | Systems Analyst | 3419 | <patricia.moura@client.gov.br> | SIAFI Integration and Auditing |
| Antônio Carlos Ribeiro | Support/Operation Analyst | 3430 | <antonio.ribeiro@client.gov.br> | Batch operation and monitoring |

### 6.2. SENARC / CGPB team

| Name | Function | Telephone | Email |
| --------------------- | --------------------------- | -------------- | ------------------------ |
| Ana Cristina Barros | SENARC Business Analyst | (61) 2030-XXXX | <ana.barros@mds.gov.br> |
| Carlos Eduardo Mendes | Coord. CGPB | (61) 2030-XXXX | <carlos.mendes@mds.gov.br> |

### 6.3. Infrastructure Support

| Area | Contact | Extension | Responsibility |
| ----------------------------- | -------------------- | ----- | --------------------------------------- |
| Mainframe Operation - Brasília | Operations Center | 3500 | Batch scheduling and monitoring |
| DBA Adabas - Central Team | DBA Coordination | 3510 | Incident Support Adabas |
| Network / Communication | NOC the organization | 3600 | Connectivity and file transmission |

> **Note:** The extensions and emails above refer to the organizational structure in force in November 2008. In case of change, consult the organization's internal telephone directory (intranet: <http://intranet.client.gov.br/catalogo>).

---

## 7. Glossary

| Acronym | Meaning |
| ------ | -------------------------------------------------------------- |
| CGPB | General Coordination of Benefits Processing |
| CNAB | National Banking Automation Center (file standard) |
| DDM | Data Definition Module (access definition Adabas in Natural) |
| DESIF | Tax Systems Development Division |
| FDT | Field Definition Table (field definition Adabas) |
| FNR | File Number (file number Adabas) |
| GDA | Global Data Area |
| ITSM | IT Service Management |
| JCL | Job Control Language |
| JES2 | Job Entry Subsystem 2 |
| LDA | Local Data Area |
| SENARC | National Secretariat for Citizenship Income |
| SIAFI | Integrated Financial Administration System |
| SIFAP | Payment Inspection and Administration System |
| SUPDE | Development Superintendence |

---

## 8. Revision History

| Version | Date | Author | Changes |
| ------ | ---------- | -------------- | ------------------------------------------------------------ |
| 1.0.0 | 10/03/2006 | F. L. Oliveira | Initial version - registration module only |
| 1.1.0 | 15/07/2006 | F. L. Oliveira | Inclusion of the validation module |
| 2.0.0 | 22/08/2007 | F. L. Oliveira | Inclusion of batch and calculation modules |
| 2.1.0 | 10/01/2008 | F. L. Oliveira | Review of contingency procedures |
| 2.2.0 | 05/06/2008 | F. L. Oliveira | Inclusion of monthly processing flow |
| 2.3.0 | 15/09/2008 | F. L. Oliveira | General review; inclusion of reference to the audit module |
| 2.3.1 | 20/11/2008 | F. L. Oliveira | Textual corrections; contact update |

> **Note:** There were no revisions to this document after November 2008.

---

## Annex A - Transaction Map

| Transaction | Program | Description |
| --------- | ------------- | ------------------------------- |
| SF01 | CADBENEF | Inclusion of beneficiary |
| SF02 | CADBENEF | Change of beneficiary |
| SF03 | CADBENEF | Logical exclusion of beneficiary |
| SF04 | CADDEPEND | Dependent registration |
| SF05 | CONSBENF | Beneficiary inquiry |
| SF06 | CADPROG | Maintenance of social programs |
| SF10 | [TO BE COMPLETED] | Audit report (?) |
| SF11 | [TO BE COMPLETED] | [TO BE COMPLETED] |

<!-- NOTE: Transactions SF10 and SF11 were mentioned at a meeting
 September/2008, but it was not possible to confirm with the technical team.
 Pending verification. -->

---

## Annex B - Pending Issues of this Document

The following sections and information remain pending documentation:

1. Details of CADBENEF validation rules (section 3.2.1)
2. Complete validation module documentation (section 3.4)
3. BATCHREL Report List (Section 3.5.2)
4. BATCHCON reconciliation rules (section 3.5.3)
5. Complete rollback procedure (section 5.4)
6. Complete transaction map (Annex A)
7. Inclusion of DDM AUDIT in the data model section (section 2.3)
8. Rules for calculating the 13th benefit - Christmas bonus (section 3.3.1)

> **Expected update:** 1st quarter of 2009 (subject to team availability).

<!-- This update was never performed. -->

---

**Document internal to the organization - Classification: RESTRICTED - Reproduction prohibited**

**the organization - the federal data processing organization**
**Development Superintendence - SUPDE**
**Tax Systems Development Division - DESIF**

---

[Back to legacy scenario](../README.md)
