<!-- markdownlint-disable MD012 MD013 MD022 MD025 MD026 MD028 MD029 MD031 MD033 MD034 MD038 MD040 MD051 MD060 -->

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
 role: "Coordenadora DESIF"
 date: "2008-12-02"
---

<!-- markdownlint-disable MD013 MD025 MD026 MD028 MD029 MD034 MD040 MD051 MD060 -->

<!-- ====================================================================== -->
<!-- MANUAL TÉCNICO DO SIFAP - VERSÃO 2.3 -->
<!-- Sistema de Fiscalização e Administração de Pagamentos -->
<!-- a organização - a federal data processing organization -->
<!-- Superintendência de Desenvolvimento - SUPDE / DESIF -->
<!-- ====================================================================== -->

# MANUAL TÉCNICO DO SIFAP - VERSÃO 2.3

**SISTEMA DE FISCALIZAÇÃO E ADMINISTRAÇÃO DE PAGAMENTOS**

---

|                                |                                            |
| ------------------------------ | ------------------------------------------ |
| **Documento:**                 | MT-SIFAP-2008-v2.3.1                       |
| **Classificação:**             | RESTRITO                                   |
| **Versão do sistema coberta:** | 2.3.1                                      |
| **Data de emissão:**           | 20/11/2008                                 |
| **Responsável:**               | Fernanda Lucia de Oliveira - SUPDE/DESIF   |
| **Aprovação técnica:**         | Roberto Carlos Meirelles - Analista Sênior |
| **Aprovação gerencial:**       | Maria Helena Costa - Coord. DESIF          |

---

> **AVISO:** Este manual refere-se à versão 2.3.1 do SIFAP. Para informações sobre versões posteriores, consultar os adendos publicados pela SUPDE/DESIF ou contatar a equipe técnica responsável.

---

## 1. Introdução

### 1.1. Objetivo do Documento

O presente manual tem por objetivo documentar os aspectos técnicos do **SIFAP - Sistema de Fiscalização e Administração de Pagamentos**, de forma a subsidiar as atividades de manutenção, operação e sustentação do sistema.

Este documento destina-se a:

- Analistas de sistemas da SUPDE/DESIF alocados ao projeto SIFAP;
- Equipe de operação de mainframe do a organização - Regional Brasília;
- Analistas de negócio da SENARC/CGPB, para fins de referência técnica;
- Equipe de DBA Adabas responsável pelo ambiente de produção.

### 1.2. Escopo

<!-- NOTA: Esta seção não foi atualizada desde 2008 -->

Este manual cobre os seguintes aspectos do SIFAP versão 2.3.1:

- Arquitetura geral do sistema;
- Descrição dos módulos e programas;
- Fluxo de processamento mensal;
- Procedimentos de contingência;
- Contatos da equipe técnica.

**Não estão no escopo deste documento:**

- Regras de negócio detalhadas (ver Manual de Regras de Negócio - em elaboração pela SENARC);
- Procedimentos de backup e recovery Adabas (ver Manual de Operação DBA - Cláudia Regina dos Santos, 2007);
- Manual do usuário operacional (ver Manual ITSM-SIFAP vol. 2).

### 1.3. Documentos Relacionados

| Código            | Título                              | Autor          | Status        |
| ----------------- | ----------------------------------- | -------------- | ------------- |
| MT-SIFAP-2008     | Este documento                      | F. L. Oliveira | Vigente       |
| MO-SIFAP-DBA-2007 | Manual de Operação DBA Adabas       | C. R. Santos   | Vigente       |
| MU-SIFAP-2006     | Manual do Usuário - Módulo Cadastro | F. L. Oliveira | Vigente       |
| ITSM-SIFAP-vol1   | Procedimentos ITSM - Incidentes     | A. C. Ribeiro  | Vigente       |
| ITSM-SIFAP-vol2   | Procedimentos ITSM - Operação       | A. C. Ribeiro  | Vigente       |
| ITSM-SIFAP-vol3   | Procedimentos ITSM - Mudanças       | [A COMPLETAR]  | Em elaboração |
| RN-SIFAP          | Manual de Regras de Negócio         | SENARC/CGPB    | Não iniciado  |

> **Nota:** O Manual ITSM-SIFAP vol. 3 (Procedimentos de Mudança) está em fase de elaboração desde junho de 2008. Previsão de conclusão: março/2009.

---

## 2. Arquitetura do Sistema

<!-- NOTA: Esta seção não foi atualizada desde 2008 -->

### 2.1. Plataforma Tecnológica

O SIFAP é desenvolvido e executado no ambiente de mainframe do a organização, utilizando a seguinte plataforma:

| Componente     | Versão   | Observações                                                                      |
| -------------- | -------- | -------------------------------------------------------------------------------- |
| **Natural**    | 6.3.12   | Linguagem de desenvolvimento - atualizada em 2005 (migração da v4.2)             |
| **Adabas**     | 7.4.3    | SGBD - atualizado em 2005 (migração da v6.1)                                     |
| **Com\*plete** | 6.3.1    | Monitor de teleprocessamento para telas 3270                                     |
| **JES2**       | z/OS 1.8 | Subsistema de entrada de jobs batch                                              |
| **CICS**       | TS 3.1   | Utilizado apenas para integração com transação de consulta CPF (Receita Federal) |
| **z/OS**       | 1.8      | Sistema operacional do mainframe                                                 |

### 2.2. Estrutura de Bibliotecas Natural

Os objetos do SIFAP estão organizados na biblioteca Natural **SIFAP**, conforme abaixo:

```
Biblioteca SIFAP
├── Programs (programas executáveis)
├── Subprograms (rotinas chamadas por CALLNAT)
├── Copycodes (blocos de código incluídos via INCLUDE)
├── Maps (telas 3270 - mapas de entrada/saída)
├── DDMs (Data Definition Modules - acesso ao Adabas)
├── LDAs (Local Data Areas)
└── GDAs (Global Data Areas)
```

### 2.3. Modelo de Dados

O SIFAP utiliza **3 DDMs** principais no Adabas:

| DDM             | Arquivo (FNR) | Descrição                        |
| --------------- | ------------- | -------------------------------- |
| BENEFICIARIO    | FNR 150       | Cadastro de beneficiários        |
| PROGRAMA-SOCIAL | FNR 151       | Parâmetros dos programas sociais |
| PAGAMENTO       | FNR 152       | Registros de pagamento           |

<!-- NOTA: O DDM AUDITORIA (FNR 153), criado em 2005 durante a migração para
 Natural 6.3, não consta nesta seção pois foi adicionado após a redação
 inicial deste capítulo. Verificar com Roberto Carlos para atualização. -->

> **Nota técnica:** A descrição detalhada dos campos de cada DDM encontra-se no Manual de Operação DBA (MO-SIFAP-DBA-2007). As FDTs (Field Definition Tables) estão sob responsabilidade da DBA Cláudia Regina dos Santos.

### 2.4. Diagrama de Componentes

```
 ┌────────────────────────────────────────────────────┐
 │ AMBIENTE MAINFRAME a organização │
 │ │
 │ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
 │ │ NATURAL │ │ ADABAS │ │ JES2 │ │
 │ │ 6.3.12 │◄──►│ 7.4.3 │ │ │ │
 │ │ │ │ │ │ Jobs │ │
 │ │ 8 Progs │ │ 3 DDMs │ │ Batch │ │
 │ │ Online │ │ │ │ │ │
 │ └────┬─────┘ └──────────┘ └────┬─────┘ │
 │ │ │ │
 │ ┌────▼─────┐ ┌─────▼────┐ │
 │ │ Com*plete│ │ BATCHPGT │ │
 │ │ Telas │ │ BATCHREL │ │
 │ │ 3270 │ │ BATCHCON │ │
 │ └────┬─────┘ └─────┬────┘ │
 └────────┼───────────────────────────────┼──────────┘
 │ │
 ┌────▼─────┐ ┌──────────▼──────────┐
 │Terminais │ │ Arquivos Externos │
 │3270 │ │ (CNAB 240 / TXT) │
 │Operadores│ │ → BB / SIAFI │
 └──────────┘ └─────────────────────┘
```

<!-- NOTA: Este diagrama não reflete os programas adicionados em 2005
 (RELAUDIT, CALCCORR) nem o DDM AUDITORIA. Solicitar atualização
 ao analista responsável. -->

---

## 3. Módulos do Sistema

<!-- NOTA: Esta seção não foi atualizada desde 2008 -->

### 3.1. Visão Geral dos Programas

O SIFAP é composto por **12 programas** principais, organizados nos seguintes módulos:

| No  | Programa  | Módulo    | Tipo         | Descrição                                                 |
| --- | --------- | --------- | ------------ | --------------------------------------------------------- |
| 01  | CADBENEF  | Cadastro  | Online       | Cadastro de beneficiários - inclusão, alteração, exclusão |
| 02  | CADDEPEND | Cadastro  | Online       | Cadastro de dependentes do beneficiário titular           |
| 03  | CADPROG   | Cadastro  | Online       | Cadastro de programas sociais e parâmetros                |
| 04  | CALCBENF  | Cálculo   | Batch/Online | Cálculo do valor do benefício por faixa/programa          |
| 05  | CALCCORR  | Cálculo   | Batch        | Cálculo de correções e reajustes anuais                   |
| 06  | VALBENEF  | Validação | Online       | Validação cadastral (CPF, NIS, duplicidade)               |
| 07  | VALELEG   | Validação | Online       | Validação de elegibilidade por regras do programa         |
| 08  | VALDOCS   | Validação | Online       | Validação de documentação comprobatória                   |
| 09  | BATCHPGT  | Batch     | Batch        | Processamento da folha de pagamento mensal                |
| 10  | BATCHREL  | Batch     | Batch        | Geração de relatórios batch                               |
| 11  | BATCHCON  | Batch     | Batch        | Conciliação financeira com SIAFI                          |
| 12  | CONSBENF  | Consulta  | Online       | Consulta de beneficiários - tela com filtros              |

<!-- NOTA: Esta lista não inclui os programas CALCDSCT, RELPGT e RELAUDIT,
 que foram adicionados ao sistema após a elaboração deste manual.
 CALCDSCT foi incluído na versão 4.0 (2015).
 RELPGT e RELAUDIT foram reestruturados/incluídos na versão 3.0 (2005).
 Este manual cobre apenas a versão 2.3.1 do sistema. -->

### 3.2. Módulo de Cadastro

#### 3.2.1. CADBENEF - Cadastro de Beneficiários

**Descrição:** Programa online para manutenção do cadastro de beneficiários. Permite inclusão, alteração e exclusão lógica de registros no DDM BENEFICIARIO.

**Transação:** SF01 (inclusão), SF02 (alteração), SF03 (exclusão)

**Funcionalidades:**

- Inclusão de novo beneficiário com validação de CPF (chama subprograma VALCPF);
- Alteração de dados cadastrais (endereço, dados bancários, situação);
- Exclusão lógica (campo BN-CD-SIT alterado para 'E');
- Registro de auditoria para todas as operações (chama subprograma LOGAUDIT);
- Vinculação ao programa social (chave: BN-CD-PROG → PS-CD-PROG).

**Observações:**

- O campo BN-QT-DEPEND (quantidade de dependentes) aceita valores de 0 a 3.
- [A COMPLETAR] - Detalhar regras de validação para alteração de dados bancários.
- [A COMPLETAR] - Documentar tratamento de beneficiário com múltiplos programas.

<!-- NOTA: O limite de dependentes foi alterado para 5 em algum momento entre
 2010 e 2015, conforme demanda da SENARC. Esta alteração não está refletida
 neste documento. Verificar no código-fonte de CADBENEF. -->

#### 3.2.2. CADDEPEND - Cadastro de Dependentes

**Descrição:** Programa online para cadastro de dependentes vinculados ao beneficiário titular.

**Transação:** SF04

**Funcionalidades:**

- Inclusão de dependente com validação de CPF e data de nascimento;
- Vinculação ao beneficiário titular (chave: BN-NR-CPF);
- Verificação de limite de dependentes (máximo: 3 por titular);
- Controle de tipo de dependente (cônjuge, filho, outro).

**Observações:**

- A validação de idade mínima/máxima de dependentes segue regras do programa social. Ver código CADBENEF para detalhes.
- [A COMPLETAR] - Documentar regras de desvinculação de dependente.

#### 3.2.3. CADPROG - Cadastro de Programas Sociais

**Descrição:** Programa online para manutenção dos parâmetros dos programas sociais.

**Transação:** SF06

**Funcionalidades:**

- Inclusão e alteração de programas sociais;
- Parametrização de faixas de valores (campos MU no DDM PROGRAMA-SOCIAL);
- Definição de regras de elegibilidade por programa;
- Controle de vigência (data início/fim).

**Observações:**

- Acesso restrito a perfil ADMIN (verificação via GDA de sessão).
- [A COMPLETAR] - Detalhar procedimento de inclusão de novo programa social.

### 3.3. Módulo de Cálculo

#### 3.3.1. CALCBENF - Cálculo de Benefícios

**Descrição:** Programa para cálculo do valor do benefício a ser pago ao beneficiário, com base nas faixas e regras definidas no DDM PROGRAMA-SOCIAL.

**Funcionalidades:**

- Cálculo do valor base conforme faixa do programa;
- Aplicação de acréscimos por dependente;
- Cálculo proporcional para benefícios com início no meio do mês;
- [A COMPLETAR] - Regras de cálculo do 13o benefício (abono natalino).

**Observações:**

- Este programa é invocado tanto online (simulação) quanto batch (processamento mensal).
- A lógica de cálculo está inteiramente no código Natural, sem parametrização externa.
- Conferir com Sr. Roberto Carlos para detalhar a fórmula de cálculo da faixa complementar.

#### 3.3.2. CALCCORR - Cálculo de Correções

**Descrição:** Programa batch para aplicação de índices de correção e reajuste sobre valores de benefícios.

**Funcionalidades:**

- Leitura de tabela interna de índices (subprograma CALCIDX);
- Aplicação de índice sobre valor base;
- Geração de log de reajuste para auditoria.

**Observações:**

- Executado anualmente em janeiro ou quando houver decreto de reajuste.
- [A COMPLETAR] - Documentar formato da tabela de índices e procedimento de atualização.

### 3.4. Módulo de Validação

[A COMPLETAR] - Seção pendente de detalhamento. Os programas VALBENEF, VALELEG e VALDOCS possuem funcionalidades auto-explicativas. Para detalhes, consultar o código-fonte ou contatar Roberto Carlos Meirelles.

### 3.5. Módulo Batch

#### 3.5.1. BATCHPGT - Processamento de Pagamento

**Descrição:** Programa batch principal do SIFAP. Responsável pelo processamento mensal da folha de pagamento.

**Agendamento:** 1o dia útil do mês, 22:00h (horário de Brasília)

**Fluxo de execução:**

1. Leitura sequencial do DDM BENEFICIARIO (registros ativos, BN-CD-SIT = 'A');
2. Para cada beneficiário, invocação do CALCBENF para obter valor do benefício;
3. Gravação de registro no DDM PAGAMENTO com status 'P' (pendente);
4. Geração do arquivo de remessa CNAB 240 para Banco do Brasil;
5. Totalização e gravação de log de processamento.

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
- O processamento é **sequencial por ordem alfabética** do nome do beneficiário (campo BN-NM-BENEF). Esta ordem é determinada pelo descritor Adabas configurado no FNR 150.
- Em caso de ABEND, ver procedimento de restart na seção 5 deste manual.

<!-- NOTA: O tempo de execução aumentou consideravelmente desde 2008 devido ao
 crescimento da base. Em 2016, reportou-se um incidente de timeout com
 processamento de 4,1 milhões de registros. -->

#### 3.5.2. BATCHREL - Relatórios Batch

**Descrição:** Geração de relatórios totalizadores pós-processamento.

**Observações:**

- Executado após conclusão bem-sucedida do BATCHPGT.
- Gera relatórios em formato texto (132 colunas) para impressora.
- [A COMPLETAR] - Listar relatórios gerados e destinatários.

#### 3.5.3. BATCHCON - Conciliação Financeira

**Descrição:** Programa de conciliação entre os pagamentos processados pelo SIFAP e as confirmações recebidas do SIAFI e dos bancos pagadores.

**Observações:**

- Executado após recebimento dos arquivos de retorno (D+2 após remessa).
- [A COMPLETAR] - Documentar formato dos arquivos de retorno e regras de conciliação.
- Para procedimentos de operação, ver Manual ITSM-SIFAP vol. 3.

---

## 4. Fluxo de Processamento Mensal

### 4.1. Calendário Padrão

O ciclo mensal de processamento do SIFAP segue o seguinte calendário:

| Dia Útil  | Atividade                                              | Responsável               | Sistema/Programa           |
| --------- | ------------------------------------------------------ | ------------------------- | -------------------------- |
| D-5       | Atualização de tabelas de parâmetros (faixas, índices) | SENARC/CGPB               | CADPROG (online)           |
| D-3       | Fechamento de cadastro - bloqueio de alterações        | Operação a organização | Procedimento manual        |
| D-2       | Validação batch de elegibilidade                       | Operação a organização | VALELEG (batch)            |
| D-1       | Conferência de totalizadores - relatório prévio        | CGPB                      | BATCHREL (modo prévio)     |
| D (1o DU) | **Processamento da folha de pagamento**                | Operação a organização | BATCHPGT                   |
| D+1       | Envio de arquivo CNAB 240 ao Banco do Brasil           | Operação a organização | Transferência manual (FTP) |
| D+2       | Envio de ordens bancárias ao SIAFI                     | Operação a organização | Procedimento SIAFI         |
| D+3       | Recebimento de arquivo de retorno bancário             | Operação a organização | Recepção FTP               |
| D+4       | Conciliação financeira                                 | Operação a organização | BATCHCON                   |
| D+5       | Geração de relatórios finais                           | CGPB                      | BATCHREL                   |
| D+10      | Fechamento do ciclo - arquivamento                     | CGPB                      | Procedimento manual        |

### 4.2. Diagrama de Fluxo

```
 ┌──────────┐ ┌──────────┐ ┌──────────┐
 │ CADPROG │ │ VALELEG │ │ BATCHREL │
 │(D-5) │────►│(D-2) │────►│(D-1) │
 │Parâmetros│ │Validação │ │Prévio │
 └──────────┘ └──────────┘ └────┬─────┘
 │
 ▼
 ┌──────────┐
 │ BATCHPGT │
 │(D=1oDU) │
 │Folha Pag.│
 └────┬─────┘
 │
 ┌─────────────┼─────────────┐
 ▼ ▼ ▼
 ┌──────────┐ ┌──────────┐ ┌──────────┐
 │Arq. CNAB │ │DDM PAGTO │ │Log Proc. │
 │(BB/CAIXA)│ │(Adabas) │ │ │
 └────┬─────┘ └──────────┘ └──────────┘
 │
 ▼
 ┌──────────┐ ┌──────────┐
 │Retorno │────►│ BATCHCON │
 │Bancário │ │(D+4) │
 │(D+3) │ │Conciliaç.│
 └──────────┘ └────┬─────┘
 │
 ▼
 ┌──────────┐
 │ BATCHREL │
 │(D+5) │
 │Relatórios│
 └──────────┘
```

### 4.3. Tratamento de Exceções

<!-- NOTA: Esta seção não foi atualizada desde 2008 -->

| Situação                       | Procedimento                                                                   | Responsável               |
| ------------------------------ | ------------------------------------------------------------------------------ | ------------------------- |
| ABEND no BATCHPGT              | Restart a partir do último checkpoint (ver seção 5.2)                          | Operação a organização |
| Arquivo CNAB rejeitado pelo BB | Correção manual e reenvio. Contatar Antônio Carlos Ribeiro.                    | Operação a organização |
| Divergência na conciliação     | Análise manual pelo CGPB. Registrar incidente no ITSM.                         | CGPB + a organização   |
| Atraso no retorno bancário     | Aguardar até D+5. Se não recebido, contatar BB via canal dedicado.             | Operação a organização |
| Solicitação de reprocessamento | Aprovação do CGPB. Procedimento de rollback conforme Manual ITSM-SIFAP vol. 3. | CGPB                      |

> **IMPORTANTE:** Para procedimentos detalhados de rollback e reprocessamento, consultar o **Manual ITSM-SIFAP vol. 3** (em elaboração - previsão: março/2009).

---

## 5. Procedimentos de Contingência

### 5.1. Plano de Contingência - Visão Geral

<!-- NOTA: Esta seção não foi atualizada desde 2008 -->

O plano de contingência do SIFAP contempla os seguintes cenários:

| Cenário                               | Nível | Procedimento                                                                                           |
| ------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------ |
| Indisponibilidade do mainframe (< 4h) | 1     | Aguardar restabelecimento. Reagendar batch se necessário.                                              |
| Indisponibilidade do mainframe (> 4h) | 2     | Acionar processamento no site de contingência (a organização-RSA). Contatar Antônio Carlos Ribeiro. |
| Corrupção de dados Adabas             | 3     | Recovery via ADASAV (último backup íntegro). Contatar Cláudia Regina dos Santos (DBA).                 |
| Falha na integração SIAFI             | 2     | Processamento manual de ordens bancárias pela CGPB. Procedimento descrito no Manual ITSM-SIFAP vol. 2. |
| Falha na transmissão CNAB             | 1     | Retransmissão manual via canal alternativo (SFTP). Contatar operação BB.                               |

### 5.2. Procedimento de Restart - BATCHPGT

Em caso de ABEND durante a execução do BATCHPGT, seguir os passos abaixo:

1. Verificar o código de ABEND no log do JES2 (JESMSGLG);
2. Identificar o último checkpoint gravado (campo CKPT-NR no SYSOUT);
3. Corrigir a condição de erro conforme tabela de ABENDs conhecidos (ver seção 5.3);
4. Reiniciar o job com parâmetro `RESTART=CKPT-nnn` (onde nnn = número do último checkpoint);
5. Monitorar a execução até conclusão normal (COND CODE = 0000);
6. Verificar totalizadores finais contra relatório prévio (D-1).

### 5.3. Tabela de ABENDs Conhecidos

| Código      | Descrição                | Causa Provável                              | Ação                                                             |
| ----------- | ------------------------ | ------------------------------------------- | ---------------------------------------------------------------- |
| S0C7        | Data exception           | Campo numérico com valor inválido no Adabas | Identificar registro corrompido via ADAORD. Corrigir ou excluir. |
| S878        | Virtual storage exceeded | Volume de processamento acima do previsto   | Aumentar REGION no JCL. Contatar operação.                       |
| S0C4        | Protection exception     | Erro de endereçamento em subprograma        | Contatar Roberto Carlos Meirelles para análise.                  |
| U4038       | Natural runtime error    | Erro de overflow em cálculo                 | Verificar valores no DDM PROGRAMA-SOCIAL (faixas).               |
| ADA-RSP 148 | Adabas timeout           | Tempo de resposta excedido                  | Verificar contenção no Adabas. Contatar DBA.                     |

### 5.4. Procedimento de Rollback

[A COMPLETAR] - Procedimento de rollback completo será documentado no Manual ITSM-SIFAP vol. 3. Enquanto isso, contatar Roberto Carlos Meirelles para orientação.

---

## 6. Contatos da Equipe Técnica

<!-- NOTA: Esta seção não foi atualizada desde 2008 -->
<!-- Vários dos contatos abaixo podem não estar mais válidos. -->
<!-- Verificar lotação atual dos servidores no sistema RH/a organização. -->

### 6.1. Equipe a organização - SUPDE/DESIF

| Nome                       | Função                           | Ramal | E-mail                          | Observação                                |
| -------------------------- | -------------------------------- | ----- | ------------------------------- | ----------------------------------------- |
| Roberto Carlos Meirelles   | Analista Sênior / Coord. Técnico | 3411  | roberto.meirelles@client.gov.br | Arquitetura e decisões técnicas           |
| Fernanda Lucia de Oliveira | Analista de Negócios             | 3415  | fernanda.oliveira@client.gov.br | Documentação e regras de negócio          |
| Marcos Antônio Ferreira    | Programador Natural Sênior       | 3418  | marcos.ferreira@client.gov.br   | Manutenção de código - módulos de cálculo |
| Cláudia Regina dos Santos  | DBA Adabas                       | 3422  | claudia.santos@client.gov.br    | Administração de banco de dados           |
| José Aparecido Lima        | Programador Natural              | -     | -                               | Aposentado desde 2005                     |
| Patrícia Helena Moura      | Analista de Sistemas             | 3419  | patricia.moura@client.gov.br    | Integração SIAFI e auditoria              |
| Antônio Carlos Ribeiro     | Analista de Suporte / Operação   | 3430  | antonio.ribeiro@client.gov.br   | Operação batch e monitoração              |

### 6.2. Equipe SENARC / CGPB

| Nome                  | Função                      | Telefone       | E-mail                   |
| --------------------- | --------------------------- | -------------- | ------------------------ |
| Ana Cristina Barros   | Analista de Negócios SENARC | (61) 2030-XXXX | ana.barros@mds.gov.br    |
| Carlos Eduardo Mendes | Coord. CGPB                 | (61) 2030-XXXX | carlos.mendes@mds.gov.br |

### 6.3. Suporte de Infraestrutura

| Área                          | Contato              | Ramal | Responsabilidade                        |
| ----------------------------- | -------------------- | ----- | --------------------------------------- |
| Operação Mainframe - Brasília | Central de Operações | 3500  | Agendamento e monitoração batch         |
| DBA Adabas - Equipe Central   | Coordenação DBA      | 3510  | Suporte a incidentes Adabas             |
| Rede / Comunicação            | NOC a organização | 3600  | Conectividade e transmissão de arquivos |

> **Nota:** Os ramais e e-mails acima referem-se à estrutura organizacional vigente em novembro de 2008. Em caso de alteração, consultar o catálogo telefônico interno do a organização (intranet: http://intranet.client.gov.br/catalogo).

---

## 7. Glossário

| Sigla  | Significado                                                    |
| ------ | -------------------------------------------------------------- |
| CGPB   | Coordenação-Geral de Processamento de Benefícios               |
| CNAB   | Centro Nacional de Automação Bancária (padrão de arquivo)      |
| DDM    | Data Definition Module (definição de acesso Adabas no Natural) |
| DESIF  | Divisão de Desenvolvimento de Sistemas Fiscais                 |
| FDT    | Field Definition Table (definição de campos Adabas)            |
| FNR    | File Number (número do arquivo Adabas)                         |
| GDA    | Global Data Area                                               |
| ITSM   | IT Service Management                                          |
| JCL    | Job Control Language                                           |
| JES2   | Job Entry Subsystem 2                                          |
| LDA    | Local Data Area                                                |
| SENARC | Secretaria Nacional de Renda de Cidadania                      |
| SIAFI  | Sistema Integrado de Administração Financeira                  |
| SIFAP  | Sistema de Fiscalização e Administração de Pagamentos          |
| SUPDE  | Superintendência de Desenvolvimento                            |

---

## 8. Histórico de Revisões

| Versão | Data       | Autor          | Alterações                                                   |
| ------ | ---------- | -------------- | ------------------------------------------------------------ |
| 1.0.0  | 10/03/2006 | F. L. Oliveira | Versão inicial - apenas módulo de cadastro                   |
| 1.1.0  | 15/07/2006 | F. L. Oliveira | Inclusão do módulo de validação                              |
| 2.0.0  | 22/08/2007 | F. L. Oliveira | Inclusão dos módulos batch e cálculo                         |
| 2.1.0  | 10/01/2008 | F. L. Oliveira | Revisão dos procedimentos de contingência                    |
| 2.2.0  | 05/06/2008 | F. L. Oliveira | Inclusão do fluxo de processamento mensal                    |
| 2.3.0  | 15/09/2008 | F. L. Oliveira | Revisão geral; inclusão de referência ao módulo de auditoria |
| 2.3.1  | 20/11/2008 | F. L. Oliveira | Correções textuais; atualização de contatos                  |

> **Nota:** Não houve revisões deste documento após novembro de 2008.

---

## Anexo A - Mapa de Transações

| Transação | Programa      | Descrição                       |
| --------- | ------------- | ------------------------------- |
| SF01      | CADBENEF      | Inclusão de beneficiário        |
| SF02      | CADBENEF      | Alteração de beneficiário       |
| SF03      | CADBENEF      | Exclusão lógica de beneficiário |
| SF04      | CADDEPEND     | Cadastro de dependentes         |
| SF05      | CONSBENF      | Consulta de beneficiário        |
| SF06      | CADPROG       | Manutenção de programas sociais |
| SF10      | [A COMPLETAR] | Relatório de auditoria (?)      |
| SF11      | [A COMPLETAR] | [A COMPLETAR]                   |

<!-- NOTA: As transações SF10 e SF11 foram mencionadas em reunião de
 setembro/2008, mas não foi possível confirmar com a equipe técnica.
 Pendente verificação. -->

---

## Anexo B - Pendências deste Documento

As seguintes seções e informações permanecem pendentes de documentação:

1. Detalhamento das regras de validação do CADBENEF (seção 3.2.1)
2. Documentação completa do módulo de validação (seção 3.4)
3. Lista de relatórios do BATCHREL (seção 3.5.2)
4. Regras de conciliação do BATCHCON (seção 3.5.3)
5. Procedimento de rollback completo (seção 5.4)
6. Mapa completo de transações (Anexo A)
7. Inclusão do DDM AUDITORIA na seção de modelo de dados (seção 2.3)
8. Regras de cálculo do 13o benefício - abono natalino (seção 3.3.1)

> **Previsão de atualização:** 1o trimestre de 2009 (sujeito a disponibilidade da equipe).

<!-- Esta atualização nunca foi realizada. -->

---

**Documento interno a organização - Classificação: RESTRITO - Reprodução proibida**

**a organização - a federal data processing organization**
**Superintendência de Desenvolvimento - SUPDE**
**Divisão de Desenvolvimento de Sistemas Fiscais - DESIF**

---

[Voltar ao cenário legado](../README.md)
