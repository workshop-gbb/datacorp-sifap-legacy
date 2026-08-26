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
<!-- MANUAL TÉCNICO DO SIFAP - VERSÃO 2.3 -->
<!-- Sistema de Fiscalização e Administração de Pagamentos -->
<!-- a organização - a organização federal de processamento de dados -->
<!-- Superintendência de Desenvolvimento - SUPDE / DESIF -->
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

<!-- NOTA: Esta seção não é atualizada desde 2008 -->

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

> **Nota:** O Manual ITSM-SIFAP vol. 3 (Procedimentos de Mudança) está em elaboração desde junho de 2008. Conclusão prevista: março/2009.

---

## 2. Arquitetura do sistema

<!-- NOTA: Esta seção não é atualizada desde 2008 -->

### 2.1. Plataforma tecnológica

O SIFAP é desenvolvido e executado no ambiente mainframe da organização, usando a seguinte plataforma:

| Componente | Versão | Observações |
| -------------- | -------- | -------------------------------------------------------------------------------- |
| **Natural** | 6.3.12 | Linguagem de desenvolvimento - atualizada em 2005 (migração da v4.2) |
| **Adabas** | 7.4.3 | SGBD - atualizado em 2005 (migração da v6.1) |
| **Com\*plete** | 6.3.1 | Monitor de teleprocessamento para telas 3270 |
| **JES2** | z/OS 1.8 | Subsistema de entrada de jobs batch |
| **CICS** | TS 3.1 | Usado somente para integração com a transação de consulta de CPF (Receita Federal) |
| **z/OS** | 1.8 | Sistema operacional do mainframe |

### 2.2. Estrutura da biblioteca Natural

Os objetos do SIFAP estão organizados na biblioteca Natural **SIFAP** da seguinte forma:

```
Biblioteca SIFAP
├── Programas (programas executáveis)
├── Subprogramas (rotinas chamadas por CALLNAT)
├── Copycodes (blocos de código incluídos por INCLUDE)
├── Maps (telas 3270 - maps de entrada/saída)
├── DDMs (Módulos de Definição de Dados - acesso ao Adabas)
├── LDAs (Áreas de Dados Locais)
└── GDAs (Áreas de Dados Globais)
```

### 2.3. Modelo de dados

O SIFAP usa **3 DDMs principais** no Adabas:

| DDM | Arquivo (FNR) | Descrição |
| --------------- | ------------- | -------------------------------- |
| BENEFICIARY | FNR 150 | Cadastro de beneficiários |
| SOCIAL-PROGRAM | FNR 151 | Parâmetros dos programas sociais |
| PAYMENT | FNR 152 | Registros de pagamentos |

<!-- NOTA: O DDM AUDIT (FNR 153), criado em 2005 durante a migração para o
 Natural 6.3, não foi incluído nesta seção porque foi adicionado depois da redação
 do início deste capítulo. Verificar a atualização com Roberto Carlos. -->

> **Nota técnica:** A descrição detalhada dos campos de cada DDM pode ser encontrada no Manual de Operação DBA (MO-SIFAP-DBA-2007). As FDTs (Tabelas de Definição de Campos) estão sob a responsabilidade da DBA Cláudia Regina dos Santos.

### 2.4. Diagrama de componentes

```mermaid
%%{init: {'theme':'neutral','themeVariables':{'fontFamily':'ui-sans-serif, system-ui, sans-serif','primaryColor':'#F5F5F5','primaryTextColor':'#171717','primaryBorderColor':'#171717','lineColor':'#525252','secondaryColor':'#FFFFFF','tertiaryColor':'#FAFAFA','background':'#FFFFFF'}}}%%
TB flowchart
    classDef step fill:#F5F5F5,stroke:#171717,color:#171717
    classDef artifact fill:#FAFAFA,stroke:#A3A3A3,color:#404040
    classDef external fill:#FFFFFF,stroke:#525252,color:#171717

    subgraph MAIN["Ambiente mainframe — a organização"]
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

<!-- NOTA: Este diagrama não reflete os programas adicionados em 2005
 (RELAUDIT, CALCCORR) nem o DDM AUDIT. Solicitar atualização
 ao analista responsável. -->

---

## 3. Módulos do sistema

<!-- NOTA: Esta seção não é atualizada desde 2008 -->

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

<!-- NOTA: Esta lista não inclui os programas CALCDSCT, RELPGT e RELAUDIT,
 que foram adicionados ao sistema depois da elaboração deste manual.
 O CALCDSCT foi incluído na versão 4.0 (2015).
 O RELPGT e o RELAUDIT foram reestruturados/incluídos na versão 3.0 (2005).
 Este manual abrange somente a versão 2.3.1 do sistema. -->

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

- O campo BN-QT-DEPEND (número de dependentes) aceita valores de 0 a 3.
- [A COMPLETAR] - Detalhar as regras de validação para alteração de dados bancários.
- [A COMPLETAR] - Documentar o tratamento de beneficiários com múltiplos programas.

<!-- NOTA: O limite de dependentes foi alterado para 5 em algum momento entre
 2010 e 2015, conforme exigido pela SENARC. Essa alteração não está refletida
 neste documento. Verificar no código-fonte do CADBENEF. -->

#### 3.2.2. CADDEPEN - Cadastro de dependentes

**Descrição:** programa online para cadastrar dependentes vinculados ao beneficiário titular.

**Transação:** SF04

**Funcionalidades:**

- Inclusão de dependente com validação de CPF e data de nascimento;
- Vínculo com o beneficiário titular (chave: BN-NR-CPF);
- Verificação do limite de dependentes (máximo: 3 por titular);
- Controle do tipo de dependente (cônjuge, filho, outro).

**Observações:**

- A validação da idade mínima/máxima dos dependentes segue as regras do programa social. Consulte o código CADBENEF para obter detalhes.
- [A COMPLETAR] - Documentar as regras de desvinculação de dependentes.

#### 3.2.3. CADPROG - Cadastro de programas sociais

**Descrição:** programa online para manter os parâmetros dos programas sociais.

**Transação:** SF06

**Funcionalidades:**

- Inclusão e alteração de programas sociais;
- Parametrização de faixas de valores (campos MU no DDM SOCPROG);
- Definição de regras de elegibilidade por programa;
- Controle de vigência (data de início/fim).

**Observações:**

- Acesso restrito ao perfil ADMIN (verificação pela GDA da sessão).
- [A COMPLETAR] - Detalhar o procedimento para inclusão de um novo programa social.

### 3.3. Módulo de cálculo

#### 3.3.1. CALCBENF - Cálculo de benefícios

**Descrição:** programa que calcula o valor do benefício a pagar, com base nas faixas e regras definidas no DDM SOCPROG.

**Funcionalidades:**

- Cálculo do valor-base conforme a faixa do programa;
- Aplicação de acréscimos por dependente;
- Cálculo proporcional para benefícios iniciados no meio do mês;
- [A COMPLETAR] - Regras para cálculo do 13º benefício (abono natalino).

**Observações:**

- Este programa é invocado tanto online (simulação) quanto em batch (processamento mensal).
- A lógica de cálculo está integralmente no código Natural, sem parametrização externa.
- Consultar o Sr. Roberto Carlos para detalhar a fórmula de cálculo da faixa adicional.

#### 3.3.2. CALCCORR - Cálculo de correções

**Descrição:** programa batch que aplica índices de correção e reajustes aos valores dos benefícios.

**Funcionalidades:**

- Leitura da tabela interna de índices (subprograma CALCIDX);
- Aplicação do índice sobre o valor-base;
- Geração de log de reajuste para auditoria.

**Observações:**

- Executado anualmente em janeiro ou quando há decreto de reajuste.
- [A COMPLETAR] - Documentar o formato da tabela de índices e o procedimento de atualização.

### 3.4. Módulo de validação

[A COMPLETAR] - Seção pendente de detalhamento. Os programas VALBENEF, VALELEG e VALDOCS têm funcionalidades autoexplicativas. Para detalhes, consulte o código-fonte ou Roberto Carlos Meirelles.

### 3.5. Módulo batch

#### 3.5.1. BATCHPGT - Processamento de pagamentos

**Descrição:** principal programa batch do SIFAP. Responsável pelo processamento mensal da folha.

**Agendamento:** 1º dia útil do mês, às 22:00 (horário de Brasília)

**Fluxo de execução:**

1. Leitura sequencial do DDM BENEFIC, o arquivo de Beneficiários (registros ativos, BN-CD-SIT = 'A');
2. Para cada beneficiário, invocar CALCBENF para obter o valor do benefício;
3. Gravação do registro no DDM PAYMENT com status 'P' (pendente);
4. Geração do arquivo de remessa CNAB 240 para o Banco do Brasil;
5. Totalização e gravação dos logs de processamento.

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

**Observações:**

- Tempo médio de execução: 2h45min (referência: out/2008, ~3.200.000 registros).
- O processamento é **sequencial em ordem alfabética** do nome do beneficiário (campo BN-NM-BENEF). Essa ordem é determinada pelo descritor Adabas configurado no FNR 150.
- Em caso de ABEND, consulte o procedimento de reinício na seção 5 deste manual.

<!-- NOTA: O tempo de execução aumentou consideravelmente desde 2008 devido ao
 crescimento da base. Em 2016, foi relatado um incidente de timeout durante o
 processamento de 4,1 milhões de registros. -->

#### 3.5.2. BATCHREL - Relatórios batch

**Descrição:** geração de relatórios totalizadores após o processamento.

**Observações:**

- Executado após a conclusão bem-sucedida do BATCHPGT.
- Gera relatórios em formato texto (132 colunas) para impressão.
- [A COMPLETAR] - Listar os relatórios gerados e os destinatários.

#### 3.5.3. BATCHCON - Conciliação financeira

**Descrição:** programa de conciliação entre os pagamentos processados pelo SIFAP e as confirmações recebidas do SIAFI e dos bancos pagadores.

**Observações:**

- Executado após o recebimento dos arquivos de retorno (D+2 após o envio).
- [A COMPLETAR] - Documentar o formato dos arquivos de retorno e as regras de conciliação.
- Para os procedimentos operacionais, consulte o Manual ITSM-SIFAP vol. 3.

---

## 4. Fluxo de processamento mensal

### 4.1. Calendário padrão

O ciclo mensal de processamento do SIFAP segue o calendário abaixo:

| Dia útil | Atividade | Responsável | Sistema/programa |
| --------- | ------------------------------------------------------ | ------------------------- | -------------------------- |
| D-5 | Atualização das tabelas de parâmetros (faixas, índices) | SENARC/CGPB | CADPROG (online) |
| D-3 | Fechamento do cadastro - bloqueio de alterações | Operação da organização | Procedimento manual |
| D-2 | Validação de elegibilidade em batch | Operação da organização | VALELEG (batch) |
| D-1 | Conferência dos totalizadores - relatório prévio | CGPB | BATCHREL (modo prévio) |
| D (1º DU) | **Processamento da folha** | Operação da organização | BATCHPGT |
| D+1 | Envio do arquivo CNAB 240 ao Banco do Brasil | Operação da organização | Transferência manual (FTP) |
| D+2 | Envio das ordens bancárias ao SIAFI | Operação da organização | Procedimento SIAFI |
| D+3 | Recebimento do arquivo de retorno bancário | Operação da organização | Recepção via FTP |
| D+4 | Conciliação financeira | Operação da organização | BATCHCON |
| D+5 | Geração dos relatórios finais | CGPB | BATCHREL |
| D+10 | Encerramento do ciclo - arquivamento | CGPB | Procedimento manual |

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

<!-- NOTA: Esta seção não é atualizada desde 2008 -->

| Situação | Procedimento | Responsável |
| ------------------------------ | ------------------------------------------------------------------------------ | ------------------------- |
| ABEND no BATCHPGT | Reiniciar a partir do último checkpoint (consulte a seção 5.2) | Operação da organização |
| Arquivo CNAB rejeitado pelo BB | Correção manual e reenvio. Contatar Antônio Carlos Ribeiro. | Operação da organização |
| Divergência na conciliação | Análise manual pela CGPB. Registrar incidente no ITSM. | CGPB + a organização |
| Atraso nos retornos bancários | Aguardar até D+5. Se não for recebido, contatar o BB pelo canal dedicado. | Operação da organização |
| Solicitação de reprocessamento | Aprovação da CGPB. Procedimento de rollback conforme o Manual ITSM-SIFAP vol. 3. | CGPB |

> **IMPORTANTE:** Para os procedimentos detalhados de rollback e reprocessamento, consulte o **Manual ITSM-SIFAP vol. 3** (em elaboração - previsão: março/2009).

---

## 5. Procedimentos de contingência

### 5.1. Plano de contingência - Visão geral

<!-- NOTA: Esta seção não é atualizada desde 2008 -->

O plano de contingência do SIFAP abrange os seguintes cenários:

| Cenário | Nível | Procedimento |
| ------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------ |
| Indisponibilidade do mainframe (< 4h) | 1 | Aguardar a recuperação. Reagendar o batch se necessário. |
| Indisponibilidade do mainframe (> 4h) | 2 | Acionar o processamento no site de contingência (a organização-RSA). Contatar Antônio Carlos Ribeiro. |
| Corrupção de dados no Adabas | 3 | Recuperação via ADASAV (último backup íntegro). Contatar Cláudia Regina dos Santos (DBA). |
| Falha de integração com o SIAFI | 2 | Processamento manual das ordens bancárias pela CGPB. Procedimento descrito no Manual ITSM-SIFAP vol. 2. |
| Falha de transmissão do CNAB | 1 | Retransmissão manual pelo canal alternativo (SFTP). Contatar a operação do BB. |

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
| S0C7 | Exceção de dados | Campo numérico com valor inválido no Adabas | Identificar o registro corrompido via ADAORD. Corrigir ou excluir. |
| S878 | Armazenamento virtual excedido | Volume de processamento acima do previsto | Aumentar REGION no JCL. Contatar a operação. |
| S0C4 | Exceção de proteção | Erro de endereçamento no subprograma | Contatar Roberto Carlos Meirelles para análise. |
| U4038 | Erro de runtime do Natural | Erro de overflow no cálculo | Verificar os valores no DDM SOCPROG (faixas). |
| ADA-RSP 148 | Timeout do Adabas | Tempo de resposta excedido | Verificar contenção no Adabas. Contatar a DBA. |

### 5.4. Procedimento de rollback

[A COMPLETAR] - O procedimento completo de rollback será documentado no Manual ITSM-SIFAP vol. 3. Até lá, consulte Roberto Carlos Meirelles para obter orientação.

---

## 6. Contatos da equipe técnica

<!-- NOTA: Esta seção não é atualizada desde 2008 -->
<!-- Vários dos contatos abaixo podem não ser mais válidos. -->
<!-- Verificar a lotação atual dos servidores no sistema de RH da organização. -->

### 6.1. Equipe da organização - SUPDE/DESIF

| Nome | Função | Ramal | Email | Observação |
| -------------------------- | -------------------------------- | ----- | ------------------------------- | ----------------------------------------- |
| Roberto Carlos Meirelles | Analista Sênior / Coord. Técnico | 3411 | <roberto.meirelles@client.gov.br> | Arquitetura e decisões técnicas |
| Fernanda Lucia de Oliveira | Analista de Negócios | 3415 | <fernanda.oliveira@client.gov.br> | Documentação e regras de negócio |
| Marcos Antônio Ferreira | Programador Natural Sênior | 3418 | <marcos.ferreira@client.gov.br> | Manutenção do código - módulos de cálculo |
| Cláudia Regina dos Santos | DBA Adabas | 3422 | <claudia.santos@client.gov.br> | Administração do banco de dados |
| José Aparecido Lima | Programador Natural | - | - | Aposentado desde 2005 |
| Patrícia Helena Moura | Analista de Sistemas | 3419 | <patricia.moura@client.gov.br> | Integração com o SIAFI e auditoria |
| Antônio Carlos Ribeiro | Analista de Suporte/Operação | 3430 | <antonio.ribeiro@client.gov.br> | Operação e monitoramento de batch |

### 6.2. Equipe SENARC / CGPB

| Nome | Função | Telefone | Email |
| --------------------- | --------------------------- | -------------- | ------------------------ |
| Ana Cristina Barros | Analista de Negócios da SENARC | (61) 2030-XXXX | <ana.barros@mds.gov.br> |
| Carlos Eduardo Mendes | Coord. da CGPB | (61) 2030-XXXX | <carlos.mendes@mds.gov.br> |

### 6.3. Suporte de infraestrutura

| Área | Contato | Ramal | Responsabilidade |
| ----------------------------- | -------------------- | ----- | --------------------------------------- |
| Operação de Mainframe - Brasília | Central de Operações | 3500 | Agendamento e monitoramento de batch |
| DBA Adabas - Equipe Central | Coordenação de DBA | 3510 | Suporte a incidentes do Adabas |
| Rede / Comunicação | NOC da organização | 3600 | Conectividade e transmissão de arquivos |

> **Nota:** Os ramais e emails acima se referem à estrutura organizacional vigente em novembro de 2008. Em caso de alteração, consulte a lista telefônica interna da organização (intranet: <http://intranet.client.gov.br/catalogo>).

---

## 7. Glossário

| Sigla | Significado |
| ------ | -------------------------------------------------------------- |
| CGPB | Coordenação-Geral de Processamento de Benefícios |
| CNAB | Centro Nacional de Automação Bancária (padrão de arquivo) |
| DDM | Módulo de Definição de Dados (definição de acesso ao Adabas no Natural) |
| DESIF | Divisão de Desenvolvimento de Sistemas Fiscais |
| FDT | Tabela de Definição de Campos (definição de campos do Adabas) |
| FNR | Número do Arquivo (número do arquivo Adabas) |
| GDA | Área de Dados Global |
| ITSM | Gerenciamento de Serviços de TI |
| JCL | Linguagem de Controle de Jobs |
| JES2 | Subsistema de Entrada de Jobs 2 |
| LDA | Área de Dados Local |
| SENARC | Secretaria Nacional de Renda de Cidadania |
| SIAFI | Sistema Integrado de Administração Financeira |
| SIFAP | Sistema de Fiscalização e Administração de Pagamentos |
| SUPDE | Superintendência de Desenvolvimento |

---

## 8. Histórico de revisões

| Versão | Data | Autor | Alterações |
| ------ | ---------- | -------------- | ------------------------------------------------------------ |
| 1.0.0 | 10/03/2006 | F. L. Oliveira | Versão inicial - somente módulo de cadastro |
| 1.1.0 | 15/07/2006 | F. L. Oliveira | Inclusão do módulo de validação |
| 2.0.0 | 22/08/2007 | F. L. Oliveira | Inclusão dos módulos batch e de cálculo |
| 2.1.0 | 10/01/2008 | F. L. Oliveira | Revisão dos procedimentos de contingência |
| 2.2.0 | 05/06/2008 | F. L. Oliveira | Inclusão do fluxo de processamento mensal |
| 2.3.0 | 15/09/2008 | F. L. Oliveira | Revisão geral; inclusão da referência ao módulo de auditoria |
| 2.3.1 | 20/11/2008 | F. L. Oliveira | Correções textuais; atualização dos contatos |

> **Nota:** Não houve revisões deste documento depois de novembro de 2008.

---

## Anexo A - Mapa de transações

| Transação | Programa | Descrição |
| --------- | ------------- | ------------------------------- |
| SF01 | CADBENEF | Inclusão de beneficiário |
| SF02 | CADBENEF | Alteração de beneficiário |
| SF03 | CADBENEF | Exclusão lógica de beneficiário |
| SF04 | CADDEPEN | Cadastro de dependente |
| SF05 | CONSBENF | Consulta de beneficiário |
| SF06 | CADPROG | Manutenção de programas sociais |
| SF10 | [A COMPLETAR] | Relatório de auditoria (?) |
| SF11 | [A COMPLETAR] | [A COMPLETAR] |

<!-- NOTA: As transações SF10 e SF11 foram mencionadas em uma reunião em
 setembro/2008, mas não foi possível confirmá-las com a equipe técnica.
 Verificação pendente. -->

---

## Anexo B - Pendências deste documento

As seguintes seções e informações continuam pendentes de documentação:

1. Detalhes das regras de validação do CADBENEF (seção 3.2.1)
2. Documentação completa do módulo de validação (seção 3.4)
3. Lista de relatórios do BATCHREL (seção 3.5.2)
4. Regras de conciliação do BATCHCON (seção 3.5.3)
5. Procedimento completo de rollback (seção 5.4)
6. Mapa completo de transações (Anexo A)
7. Inclusão do DDM AUDIT na seção do modelo de dados (seção 2.3)
8. Regras para cálculo do 13º benefício - abono natalino (seção 3.3.1)

> **Atualização prevista:** 1º trimestre de 2009 (sujeita à disponibilidade da equipe).

<!-- Esta atualização nunca foi realizada. -->

---

**Documento interno da organização - Classificação: RESTRITO - Reprodução proibida**

**a organização - a organização federal de processamento de dados**
**Superintendência de Desenvolvimento - SUPDE**
**Divisão de Desenvolvimento de Sistemas Fiscais - DESIF**

---

[Voltar ao cenário legado](../README.md)
