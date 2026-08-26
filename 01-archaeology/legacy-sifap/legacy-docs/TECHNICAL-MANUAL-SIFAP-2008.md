---
title: "Manual Técnico do SIFAP - Sistema de Fiscalização e Administração de Pagamentos"
author: "Fernanda Lucia de Oliveira - SUPDE/DESIF"
date: "2008-11-20"
version: "2.3.1"
classification: "RESTRITO"
distribution: "SUPDE/DESIF, CGTI/MDAS, SENARC/CGPB"
revision_history:

- version: "1.0.0"
 date: "2006-03-10"
 author: "Fernanda Lucia de Oliveira"
 description: "Versão inicial - módulo de cadastro"
- version: "2.0.0"
 date: "2007-08-22"
 author: "Fernanda Lucia de Oliveira"
 description: "Inclusão dos módulos de cálculo e batch"
- version: "2.3.0"
 date: "2008-09-15"
 author: "Fernanda Lucia de Oliveira"
 description: "Revisão geral, inclusão do módulo de auditoria"
- version: "2.3.1"
 date: "2008-11-20"
 author: "Fernanda Lucia de Oliveira"
 description: "Correções textuais e inclusão de contatos atualizados"
approval:
- name: "Roberto Carlos Meirelles"
 role: "Analista de Sistemas Sênior - SUPDE/DESIF"
 date: "2008-11-25"
- name: "Maria Helena Costa"
 role: "Coordenadora da DESIF"
 date: "2008-12-02"

---

> [!NOTE]
> Este é um documento histórico reconstituído para o exercício de arqueologia da imersão SIFAP 2.0. Ele simula o Manual Técnico versão 2.3.1 (2008), como teria sido produzido pela equipe SUPDE/DESIF. A linguagem da época e os nomes de pessoas, unidades e procedimentos foram preservados intencionalmente. **Este documento não deve ser usado como especificação atual do sistema.** Seções marcadas como `[A COMPLETAR]` e comentários internos sobre informações desatualizadas fazem parte do exercício: representam lacunas reais de documentação que a equipe deve investigar.

<!-- ====================================================================== -->
<!-- SIFAP TECHNICAL MANUAL - VERSION 2.3 -->
<!-- Payment Inspection and Administration System -->
<!-- the organization - the federal data processing organization -->
<!-- Development Superintendency - SUPDE / DESIF -->
<!-- ====================================================================== -->

# MANUAL TÉCNICO DO SIFAP - VERSÃO 2.3

**SISTEMA DE FISCALIZAÇÃO E ADMINISTRAÇÃO DE PAGAMENTOS**

---

|                                |                                            |
| ------------------------------ | ------------------------------------------ |
| **Documento:** | MT-SIFAP-2008-v2.3.1 |
| **Classificação:** | RESTRITO |
| **Versão do sistema abrangida:** | 2.3.1 |
| **Data de emissão:** | 20/11/2008 |
| **Responsável:** | Fernanda Lucia de Oliveira - SUPDE/DESIF |
| **Aprovação técnica:** | Roberto Carlos Meirelles - Analista Sênior |
| **Aprovação gerencial:** | Maria Helena Costa - Coord. DESIF |

---

> [!WARNING]
> Este manual se refere à versão 2.3.1 do SIFAP. Para informações sobre versões posteriores, consulte os adendos publicados pela SUPDE/DESIF ou entre em contato com a equipe técnica responsável.

---

## 1. Introdução

### 1.1. Finalidade do documento

Este manual documenta os aspectos técnicos do **SIFAP, Sistema de Fiscalização e Administração de Pagamentos**, para apoiar as atividades de manutenção, operação e suporte do sistema.

Este documento destina-se a:

- Analistas de sistemas da SUPDE/DESIF alocados ao projeto SIFAP;
- Equipe de operação de mainframe da organização, Regional Brasília;
- Analistas de negócio da SENARC/CGPB, para referência técnica;
- Equipe de DBA Adabas responsável pelo ambiente de produção.

### 1.2. Escopo

<!-- NOTE: This section has not been updated since 2008 -->

Este manual abrange os seguintes aspectos da versão 2.3.1 do SIFAP:

- Arquitetura geral do sistema;
- Descrição dos módulos e programas;
- Fluxo de processamento mensal;
- Procedimentos de contingência;
- Contatos da equipe técnica.

**Não fazem parte do escopo deste documento:**

- Regras de negócio detalhadas (consulte o Manual de Regras de Negócio, em elaboração pela SENARC);
- Procedimentos de backup e recuperação do Adabas (consulte o Manual de Operação DBA, Cláudia Regina dos Santos, 2007);
- Manual do usuário operacional (consulte o Manual ITSM-SIFAP vol. 2).

### 1.3. Documentos relacionados

| Código | Título | Autor | Situação |
| ----------------- | ----------------------------------- | -------------- | ------------- |
| MT-SIFAP-2008 | Este documento | F. L. Oliveira | Atual |
| MO-SIFAP-DBA-2007 | Manual de Operação DBA Adabas | C.R. Santos | Atual |
| MU-SIFAP-2006 | Manual do Usuário, módulo de cadastro | F. L. Oliveira | Atual |
| ITSM-SIFAP-vol1 | Procedimentos ITSM, incidentes | A. C. Ribeiro | Atual |
| ITSM-SIFAP-vol2 | Procedimentos ITSM, operação | A. C. Ribeiro | Atual |
| ITSM-SIFAP-vol3 | Procedimentos ITSM, mudanças | [A COMPLETAR] | Em elaboração |
| RN-SIFAP | Manual de Regras de Negócio | SENARC/CGPB | Não iniciado |

> **Note:** The ITSM-SIFAP Manual vol. 3 (Change Procedures) has been in the preparation phase since June 2008. Expected completion: March/2009.

---

## 2. Arquitetura do sistema

<!-- NOTE: This section has not been updated since 2008 -->

### 2.1. Plataforma tecnológica

O SIFAP é desenvolvido e executado no ambiente mainframe da organização, usando a seguinte plataforma:

| Componente | Versão | Observações |
| -------------- | -------- | -------------------------------------------------------------------------------- |
| **Natural** | 6.3.12 | Development language - updated in 2005 (migration from v4.2) |
| **Adabas** | 7.4.3 | DBMS - updated in 2005 (migration from v6.1) |
| **Com\*plete** | 6.3.1 | Teleprocessing monitor for 3270 screens |
| **JES2** | z/OS 1.8 | Batch job entry subsystem |
| **CICS** | TS 3.1 | Used only for integration with query transaction CPF (Federal Revenue) |
| **z/OS** | 1.8 | Mainframe Operating System |

### 2.2. Estrutura da biblioteca Natural

Os objetos do SIFAP estão organizados na biblioteca Natural **SIFAP** da seguinte forma:

```
Biblioteca SIFAP
├── Programs (programas executáveis)
├── Subprograms (rotinas chamadas por CALLNAT)
├── Copycodes (blocos de código incluídos por INCLUDE)
├── Maps (telas 3270 - maps de entrada/saída)
├── DDMs (Data Definition Modules - acesso ao Adabas)
├── LDAs (Local Data Areas)
└── GDAs (Global Data Areas)
```

### 2.3. Modelo de dados

O SIFAP usa **3 DDMs principais** no Adabas:

| DDM | Arquivo (FNR) | Descrição |
| --------------- | ------------- | -------------------------------- |
| BENEFICIARY | FNR 150 | Beneficiary registration |
| SOCIAL-PROGRAM | FNR 151 | Parameters of social programs |
| PAYMENT | FNR 152 | Payment records |

<!-- NOTE: The DDM AUDIT (FNR 153), created in 2005 during the migration to
 Natural 6.3, not included in this section as it was added after writing
 beginning of this chapter. Check with Roberto Carlos for update. -->

> **Technical note:** The detailed description of the fields of each DDM can be found in the DBA Operation Manual (MO-SIFAP-DBA-2007). The FDTs (Field Definition Tables) are under the responsibility of DBA Cláudia Regina dos Santos.

### 2.4. Diagrama de componentes

```mermaid
%%{init: {'theme':'neutral','themeVariables':{'fontFamily':'ui-sans-serif, system-ui, sans-serif','primaryColor':'#F5F5F5','primaryTextColor':'#171717','primaryBorderColor':'#171717','lineColor':'#525252','secondaryColor':'#FFFFFF','tertiaryColor':'#FAFAFA','background':'#FFFFFF'}}}%%
TB flowchart
    classDef step fill:#F5F5F5,stroke:#171717,color:#171717
    classDef artifact fill:#FAFAFA,stroke:#A3A3A3,color:#404040
    classDef external fill:#FFFFFF,stroke:#525252,color:#171717

    subgraph MAIN["Ambiente mainframe — the organization"]
        NAT["Natural 6.3.12<br/>8 programas online"]:::step
        ADA["Adabas 7.4.3<br/>3 DDMs"]:::step
        JES["JES2 / z/OS 1.8<br/>Jobs batch"]:::step
        NAT <--> ADA
        JES --> ADA

        COMPLETE["Comp*plete<br/>Telas 3270"]:::step
        BATCH["BATCHPGT<br/>BATCHREL<br/>BATCHCON"]:::step
        NAT --> COMPLETE
        JES --> BATCH
    end

    TERM["Terminais 3270<br/>Operadores"]:::external
    EXTFILES["Arquivos externos<br/>CNAB 240 / TXT<br/>BB / SIAFI"]:::external

    COMPLETE --> END
    BATCH --> EXTFILES
```

<!-- NOTE: This diagram does not reflect programs added in 2005
 (RELAUDIT, CALCCORR) nor the DDM AUDIT. Request update
 to the responsible analyst. -->

---

## 3. Módulos do sistema

<!-- NOTE: This section has not been updated since 2008 -->

### 3.1. Visão geral dos programas

O SIFAP é composto por **12 programas principais**, organizados nos seguintes módulos:

| Nº | Programa | Módulo | Tipo | Descrição |
| --- | --------- | --------- | ------------ | --------------------------------------------------------- |
| 01 | CADBENEF | Cadastro | Online | Cadastro de beneficiário, inclusão, alteração e exclusão |
| 02 | CADDEPEN | Cadastro | Online | Cadastro de dependentes do beneficiário |
| 03 | CADPROG | Cadastro | Online | Cadastro de programas sociais e parâmetros |
| 04 | CALCBENF | Cálculo | Batch/Online | Cálculo do valor do benefício por faixa/programa |
| 05 | CALCCORR | Cálculo | Batch | Cálculo de correções e reajustes anuais |
| 06 | VALBENEF | Validação | Online | Validação cadastral (CPF, NIS, duplicidade) |
| 07 | VALELEG | Validação | Online | Validação de elegibilidade conforme regras do programa |
| 08 | VALDOCS | Validação | Online | Validação de documentação comprobatória |
| 09 | BATCHPGT | Batch | Batch | Processamento mensal da folha |
| 10 | BATCHREL | Batch | Batch | Geração de relatórios batch |
| 11 | BATCHCON | Batch | Batch | Conciliação financeira com o SIAFI |
| 12 | CONSBENF | Consulta | Online | Consulta de beneficiário, tela com filtros |

<!-- NOTE: This list does not include programs CALCDSCT, RELPGT and RELAUDIT,
 which were added to the system after the preparation of this manual.
 CALCDSCT was included in version 4.0 (2015).
 RELPGT and RELAUDIT were restructured/included in version 3.0 (2005).
 This manual only covers system version 2.3.1. -->

### 3.2. Módulo de cadastro

#### 3.2.1. CADBENEF - Cadastro de beneficiário

**Descrição:** programa online para manutenção do cadastro de beneficiários. Permite inclusão, alteração e exclusão lógica de registros no DDM BENEFIC, o arquivo de Beneficiários.

**Transação:** SF01 (inclusão), SF02 (alteração), SF03 (exclusão)

**Funcionalidades:**

- Inclusão de novo beneficiário com validação de CPF (subprograma VALCPF);
- Alteração de dados cadastrais (endereço, dados bancários, situação);
- Exclusão lógica (campo BN-CD-SIT alterado para 'E');
- Log de auditoria para todas as operações (subprograma LOGAUDIT);
- Vínculo com o programa social (chave: BN-CD-PROG → PS-CD-PROG).

**Observações:**

- The BN-QT-DEPEND field (number of dependents) accepts values ​​from 0 to 3.
- [TO BE COMPLETED] - Detail validation rules for changing bank details.
- [TO BE COMPLETED] - Document beneficiary treatment with multiple programs.

<!-- NOTE: The dependent limit was changed to 5 sometime between
 2010 and 2015, as required by SENARC. This change is not reflected
 in this document. Check in the source code of CADBENEF. -->

#### 3.2.2. CADDEPEN - Cadastro de dependentes

**Descrição:** programa online para cadastrar dependentes vinculados ao beneficiário titular.

**Transaction:** SF04

**Features:**

- Inclusion of dependent with validation of CPF and date of birth;
- Link to the titular beneficiary (key: BN-NR-CPF);
- Verification of dependent limit (maximum: 3 per holder);
- Control of type of dependent (spouse, child, other).

**Observations:**

- Validation of the minimum/maximum age of dependents follows the rules of the social program. See code CADBENEF for details.
- [TO BE COMPLETED] - Document dependent separation rules.

#### 3.2.3. CADPROG - Cadastro de programas sociais

**Descrição:** programa online para manter os parâmetros dos programas sociais.

**Transaction:** SF06

**Features:**

- Inclusion and alteration of social programs;
- Parameterization of value ranges (fields MU in DDM SOCPROG);
- Definition of eligibility rules per program;
- Validity control (start/end date).

**Observations:**

- Restricted access to the ADMIN profile (check via session GDA).
- [TO BE COMPLETED] - Detail the procedure for including a new social program.

### 3.3. Módulo de cálculo

#### 3.3.1. CALCBENF - Cálculo de benefícios

**Descrição:** programa que calcula o valor do benefício a pagar, com base nas faixas e regras definidas no DDM SOCPROG.

**Features:**

- Calculation of the base value according to the program range;
- Application of increases per dependent;
- Proportional calculation for benefits starting in the middle of the month;
- [TO BE COMPLETED] - Rules for calculating the 13th benefit (Christmas bonus).

**Observations:**

- This program is invoked both online (simulation) and batch (monthly processing).
- The calculation logic is entirely in the Natural code, without external parameterization.
- Consult with Mr. Roberto Carlos to detail the formula for calculating the additional band.

#### 3.3.2. CALCCORR - Cálculo de correções

**Descrição:** programa batch que aplica índices de correção e reajustes aos valores dos benefícios.

**Features:**

- Reading of internal index table (subprogram CALCIDX);
- Application of index on base value;
- Generation of readjustment log for auditing.

**Observations:**

- Executed annually in January or when there is an adjustment decree.
- [TO BE COMPLETED] - Document index table format and update procedure.

### 3.4. Módulo de validação

[A COMPLETAR] - Seção pendente de detalhamento. Os programas VALBENEF, VALELEG e VALDOCS têm funcionalidades autoexplicativas. Para detalhes, consulte o código-fonte ou Roberto Carlos Meirelles.

### 3.5. Módulo batch

#### 3.5.1. BATCHPGT - Processamento de pagamentos

**Descrição:** principal programa batch do SIFAP. Responsável pelo processamento mensal da folha.

**Agendamento:** 1º dia útil do mês, às 22:00 (horário de Brasília)

**Fluxo de execução:**

1. Sequential reading of DDM BENEFIC, the Beneficiary file (active registers, BN-CD-SIT = 'A');
2. For each beneficiary, invoke CALCBENF to obtain the benefit value;
3. Record recording on DDM PAYMENT with status 'P' (pending);
4. Generation of the remittance file CNAB 240 for Banco do Brasil;
5. Totalization and recording of processing logs.

**Parâmetros JCL:**

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

#### 3.5.2. BATCHREL - Relatórios batch

**Descrição:** geração de relatórios totalizadores após o processamento.

**Observations:**

- Executed upon successful completion of BATCHPGT.
- Generates reports in text format (132 columns) for printer.
- [TO BE COMPLETED] - List reports generated and recipients.

#### 3.5.3. BATCHCON - Conciliação financeira

**Descrição:** programa de conciliação entre os pagamentos processados pelo SIFAP e as confirmações recebidas do SIAFI e dos bancos pagadores.

**Observations:**

- Executed upon receipt of return files (D+2 after shipment).
- [TO BE COMPLETED] - Document format of return files and reconciliation rules.
- For operating procedures, see Manual ITSM-SIFAP vol. 3.

---

## 4. Fluxo de processamento mensal

### 4.1. Calendário padrão

O ciclo mensal de processamento do SIFAP segue o calendário abaixo:

| Dia útil | Atividade | Responsável | Sistema/programa |
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

### 4.2. Diagrama de fluxo

```mermaid
%%{init: {'theme':'neutral','themeVariables':{'fontFamily':'ui-sans-serif, system-ui, sans-serif','primaryColor':'#F5F5F5','primaryTextColor':'#171717','primaryBorderColor':'#171717','lineColor':'#525252','secondaryColor':'#FFFFFF','tertiaryColor':'#FAFAFA','background':'#FFFFFF'}}}%%
TB flowchart
    classDef step fill:#F5F5F5,stroke:#171717,color:#171717
    classDef artifact fill:#FAFAFA,stroke:#A3A3A3,color:#404040

    CADPROG["CADPROG<br/>(D-5)<br/>Atualização de parâmetros"]:::step
    VALELEG_PRE["VALELEG<br/>(D-2)<br/>Validação de elegibilidade"]:::step
    BATCHREL_PRE["BATCHREL<br/>(D-1)<br/>Prévia"]:::step
    BATCHPGT["BATCHPGT<br/>(D = 1º DU)<br/>Folha"]:::step
    CNAB["Arquivo CNAB<br/>BB"]:::artifact
    DDM_PAGTO["DDM PAYMENT<br/>(Adabas)"]:::artifact
    LOG["Log de processamento"]:::artifact
    RETURN["Retorno bancário<br/>(D+3)"]:::artifact
    BATCHCON["BATCHCON<br/>(D+4)<br/>Conciliação"]:::step
    BATCHREL_POS["BATCHREL<br/>(D+5)<br/>Relatórios finais"]:::step

    CADPROG --> VALELEG_PRE --> BATCHREL_PRE --> BATCHPGT
    BATCHPGT --> CNAB
    BATCHPGT --> DDM_PAGTO
    BATCHPGT --> LOG
    CNAB --> RETURN
    RETURN --> BATCHCON
    BATCHCON --> BATCHREL_POS
```

### 4.3. Tratamento de exceções

<!-- NOTE: This section has not been updated since 2008 -->

| Situação | Procedimento | Responsável |
| ------------------------------ | ------------------------------------------------------------------------------ | ------------------------- |
| ABEND on BATCHPGT | Restart from last checkpoint (see section 5.2) | Operation the organization |
| File CNAB rejected by BB | Manual correction and resubmission. Contact Antônio Carlos Ribeiro.                    | Operation the organization |
| Divergence in conciliation | Manual analysis by CGPB. Register incident in ITSM.                         | CGPB + the organization |
| Delay in bank returns | Wait until D+5. If not received, contact BB via dedicated channel.             | Operation the organization |
| Reprocessing Request | CGPB approval. Rollback procedure according to Manual ITSM-SIFAP vol. 3. | CGPB |

> **IMPORTANT:** For detailed rollback and reprocessing procedures, see **Manual ITSM-SIFAP vol. 3** (in preparation - forecast: March/2009).

---

## 5. Procedimentos de contingência

### 5.1. Plano de contingência - Visão geral

<!-- NOTE: This section has not been updated since 2008 -->

O plano de contingência do SIFAP abrange os seguintes cenários:

| Cenário | Nível | Procedimento |
| ------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------ |
| Mainframe unavailability (< 4h) | 1 | Wait for recovery. Reschedule batch if necessary.                                              |
| Mainframe unavailability (> 4h) | 2 | Trigger processing at the contingency site (the organization-RSA). Contact Antônio Carlos Ribeiro. |
| Data corruption Adabas | 3 | Recovery via ADASAV (last healthy backup). Contact Cláudia Regina dos Santos (DBA).                 |
| Integration failure SIAFI | 2 | Manual processing of bank orders by CGPB. Procedure described in Manual ITSM-SIFAP vol. 2. |
| Transmission failure CNAB | 1 | Manual retransmission via alternate channel (SFTP). Contact operation BB.                               |

### 5.2. Procedimento de reinício - BATCHPGT

Em caso de ABEND durante a execução do BATCHPGT, siga os passos abaixo:

1. Verifique o código ABEND no log JES2 (JESMSGLG);
2. Identifique o último checkpoint registrado (campo CKPT-NR em SYSOUT);
3. Corrija a condição de erro conforme a tabela de ABENDs conhecidos (consulte a seção 5.3);
4. Reinicie o job com o parâmetro `RESTART=CKPT-nnn` (onde nnn = número do último checkpoint);
5. Monitore a execução até a conclusão normal (COND CODE = 0000);
6. Compare os totais finais com o relatório prévio (D-1).

### 5.3. Tabela de ABENDs conhecidos

| Código | Descrição | Causa provável | Ação |
| ----------- | ------------------------ | ------------------------------------------- | ---------------------------------------------------------------- |
| S0C7 | Data exception | Numeric field with invalid value in Adabas | Identify corrupt registry via ADAORD. Correct or delete. |
| S878 | Virtual storage exceeded | Processing volume above forecast | Increase REGION on JCL. Contact operation.                       |
| S0C4 | Protection exception | Addressing error in subprogram | Contact Roberto Carlos Meirelles for analysis.                  |
| U4038 | Natural runtime error | Overflow error in calculation | Check values ​​in DDM SOCPROG (ranges).                      |
| ADA-RSP 148 | Adabas timeout | Response time exceeded | Check containment on Adabas. Contact DBA.                     |

### 5.4. Procedimento de rollback

[A COMPLETAR] - O procedimento completo de rollback será documentado no Manual ITSM-SIFAP vol. 3. Até lá, consulte Roberto Carlos Meirelles para obter orientação.

---

## 6. Contatos da equipe técnica

<!-- NOTE: This section has not been updated since 2008 -->
<!-- Several of the contacts below may no longer be valid. -->
<!-- Check current server capacity in the HR system/organization. -->

### 6.1. Equipe da organização - SUPDE/DESIF

| Nome | Função | Ramal | Email | Observação |
| -------------------------- | -------------------------------- | ----- | ------------------------------- | ----------------------------------------- |
| Roberto Carlos Meirelles | Senior Analyst / Coord. Technical | 3411 | <roberto.meirelles@client.gov.br> | Architecture and technical decisions |
| Fernanda Lucia de Oliveira | Business Analyst | 3415 | <fernanda.oliveira@client.gov.br> | Documentation and business rules |
| Marcos Antônio Ferreira | Senior Natural Programmer | 3418 | <marcos.ferreira@client.gov.br> | Code maintenance - calculation modules |
| Cláudia Regina dos Santos | DBA Adabas | 3422 | <claudia.santos@client.gov.br> | Database Administration |
| José Aparecido Lima | Natural Programmer | - | - | Retired since 2005 |
| Patrícia Helena Moura | Systems Analyst | 3419 | <patricia.moura@client.gov.br> | SIAFI Integration and Auditing |
| Antônio Carlos Ribeiro | Support/Operation Analyst | 3430 | <antonio.ribeiro@client.gov.br> | Batch operation and monitoring |

### 6.2. Equipe SENARC / CGPB

| Name | Function | Telephone | Email |
| --------------------- | --------------------------- | -------------- | ------------------------ |
| Ana Cristina Barros | SENARC Business Analyst | (61) 2030-XXXX | <ana.barros@mds.gov.br> |
| Carlos Eduardo Mendes | Coord. CGPB | (61) 2030-XXXX | <carlos.mendes@mds.gov.br> |

### 6.3. Suporte de infraestrutura

| Área | Contato | Ramal | Responsabilidade |
| ----------------------------- | -------------------- | ----- | --------------------------------------- |
| Mainframe Operation - Brasília | Operations Center | 3500 | Batch scheduling and monitoring |
| DBA Adabas - Central Team | DBA Coordination | 3510 | Incident Support Adabas |
| Network / Communication | NOC the organization | 3600 | Connectivity and file transmission |

> **Note:** The extensions and emails above refer to the organizational structure in force in November 2008. In case of change, consult the organization's internal telephone directory (intranet: <http://intranet.client.gov.br/catalogo>).

---

## 7. Glossário

| Sigla | Significado |
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

## 8. Histórico de revisões

| Versão | Data | Autor | Alterações |
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

## Anexo A - Mapa de transações

| Transação | Programa | Descrição |
| --------- | ------------- | ------------------------------- |
| SF01 | CADBENEF | Inclusion of beneficiary |
| SF02 | CADBENEF | Change of beneficiary |
| SF03 | CADBENEF | Logical exclusion of beneficiary |
| SF04 | CADDEPEN | Dependent registration |
| SF05 | CONSBENF | Beneficiary inquiry |
| SF06 | CADPROG | Maintenance of social programs |
| SF10 | [TO BE COMPLETED] | Audit report (?) |
| SF11 | [TO BE COMPLETED] | [TO BE COMPLETED] |

<!-- NOTE: Transactions SF10 and SF11 were mentioned at a meeting
 September/2008, but it was not possible to confirm with the technical team.
 Pending verification. -->

---

## Anexo B - Pendências deste documento

As seguintes seções e informações continuam pendentes de documentação:

1. Details of CADBENEF validation rules (section 3.2.1)
2. Complete validation module documentation (section 3.4)
3. BATCHREL Report List (Section 3.5.2)
4. BATCHCON reconciliation rules (section 3.5.3)
5. Complete rollback procedure (section 5.4)
6. Complete transaction map (Annex A)
7. Inclusion of DDM AUDIT in the data model section (section 2.3)
8. Rules for calculating the 13th benefit - Christmas bonus (section 3.3.1)

> **Atualização prevista:** 1º trimestre de 2009 (sujeita à disponibilidade da equipe).

<!-- This update was never performed. -->

---

**Documento interno da organização - Classificação: RESTRITO - Reprodução proibida**

**the organization - the federal data processing organization**
**Development Superintendence - SUPDE**
**Tax Systems Development Division - DESIF**

---

[Voltar ao cenário legado](../README.md)
