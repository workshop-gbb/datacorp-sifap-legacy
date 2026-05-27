<!-- markdownlint-disable MD013 MD025 MD026 MD028 MD029 MD034 MD040 MD051 MD060 -->

# SIFAP - Sistema de Fiscalização e Administração de Pagamentos

![LEGADO SIFAP 1.0](https://img.shields.io/badge/LEGADO-SIFAP%201.0-F25022?style=for-the-badge) ![ANOS 29](https://img.shields.io/badge/ANOS-29-1A1A1A?style=for-the-badge) ![LINGUAGEM Natural+Adabas](https://img.shields.io/badge/LINGUAGEM-Natural%2BAdabas-737373?style=for-the-badge)

> 🗺 **Você está aqui:** [Kit PT-BR](../../README.md) → [Estágio 1](../README.md) → **Legado SIFAP**


> **Para quem é isto?** Quem vai abrir o legado SIFAP no Estágio 1.
>
> **O que você terá ao final desta leitura:**
>
> 1. Histórico do sistema SIFAP (1997–2024)
> 2. Quais 15 programas Natural e 4 DDMs existem
> 3. Por que o relatório do TCU exige formato específico
> 4. Link para o guia de leitura de Natural sem saber a sintaxe

> **Classificação:** Documento Interno - a organização / SUPDE / DESIF
> **Versão do sistema:** 4.1.2
> **Ambiente:** Produção - Mainframe a organização / Regional Brasília
> **Linguagem:** Natural 6.3.12 | Base de dados: Adabas 7.4.3

---

## 1. Finalidade do Sistema

O **SIFAP - Sistema de Fiscalização e Administração de Pagamentos** é responsável pela gestão, controle e fiscalização dos pagamentos de benefícios sociais administrados pelo Governo Federal, com abrangência nacional.

O sistema atende às seguintes demandas operacionais:

- **Cadastro e manutenção** de beneficiários de programas sociais federais;
- **Cálculo e processamento** da folha mensal de pagamentos;
- **Fiscalização e auditoria** dos pagamentos realizados, com cruzamento de dados cadastrais;
- **Geração de arquivos de remessa** para instituições financeiras pagadoras;
- **Conciliação financeira** com o SIAFI (Sistema Integrado de Administração Financeira do Governo Federal);
- **Emissão de relatórios gerenciais** e operacionais para os órgãos gestores.

### 1.1. Órgãos Atendidos

| Sigla     | Órgão                                              | Vinculação                                     |
| --------- | -------------------------------------------------- | ---------------------------------------------- |
| MDAS      | Ministério do Desenvolvimento e Assistência Social | Gestão dos programas de transferência de renda |
| SENARC    | Secretaria Nacional de Renda de Cidadania          | Normatização e acompanhamento dos benefícios   |
| CGPB      | Coordenação-Geral de Processamento de Benefícios   | Operação direta do processamento mensal        |
| DEFIS     | Departamento de Fiscalização                       | Auditoria e controle de pagamentos indevidos   |
| CGTI/MDAS | Coordenação-Geral de Tecnologia da Informação      | Interface técnica com a organização         |

O SIFAP opera como sistema estruturante para o ciclo de pagamento de benefícios, sendo considerado **sistema de missão crítica** pelo Comitê de Governança de TI do MDAS.

---

## 2. Histórico

### 2.1. Linha do Tempo

| Ano      | Evento                                         | Observações                                                                                                                                                                                                         |
| -------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1997** | Desenvolvimento inicial do SIFAP               | Natural 4.2 / Adabas 6.1. Equipe de 8 analistas da SUPDE/DESIF, coordenada por Roberto Meirelles. Prazo original: 14 meses. Entregue em 18 meses.                                                                   |
| **1998** | Entrada em produção (v1.0)                     | Módulos CADBENEF, CADPROG, CONSBENF. Cadastro inicial de 1,2 milhão de beneficiários migrados do sistema anterior (SIPAG/DOS).                                                                                      |
| **1999** | Primeira grande atualização (v2.0)             | Implementação do processamento batch para ciclos mensais de pagamento. Programas BATCHPGT, BATCHREL. Integração com Banco do Brasil para remessa de arquivos CNAB 240.                                              |
| **2002** | Integração com SIAFI (v2.5)                    | Módulo de conciliação financeira. Programa BATCHCON para reconciliação automática de ordens bancárias. Homologação pela STN.                                                                                        |
| **2005** | Migração tecnológica (v3.0)                    | Atualização para Natural 6.3 / Adabas 7.4. Novo módulo de auditoria (RELAUDIT). Criação do DDM AUDITORIA. Refatoração parcial dos programas de cálculo.                                                             |
| **2008** | Esforço de documentação técnica                | Projeto de documentação conduzido por Fernanda Oliveira (analista de negócios). **Parcialmente concluído** - cobre apenas os módulos de cadastro. Os módulos de cálculo e batch permanecem sem documentação formal. |
| **2012** | Tentativa de documentação de regras de negócio | Iniciativa da CGTI/MDAS. Levantamento interrompido após saída de 3 analistas-chave por aposentadoria. Documento produzido: "RN-SIFAP-2012-parcial.doc" (47 páginas, incompleto).                                    |
| **2015** | Última funcionalidade significativa (v4.0)     | Módulo CALCDSCT - cálculo de descontos e deduções legais. Implementado por Marcos Antônio Ferreira (último programador Natural com conhecimento integral do sistema).                                               |
| **2018** | Última manutenção (v4.1.2)                     | Correções de segurança (patches Adabas). Ajuste no BATCHPGT para tratamento de timeout. Atualização de tabelas de faixas de desconto. Nenhuma funcionalidade nova adicionada.                                       |

### 2.2. Observação sobre Continuidade

Desde 2018, o SIFAP opera em **modo de manutenção mínima**. Não há previsão de novas funcionalidades. O contrato de sustentação contempla apenas correções emergenciais e ajustes em tabelas de parâmetros.

---

## 3. Equipe Original

A equipe que desenvolveu e manteve o SIFAP ao longo dos anos é listada abaixo. **A maioria dos membros já se aposentou ou foi transferida para outras unidades**, o que representa risco significativo de perda de conhecimento.

| Nome                          | Função                                    | Período   | Situação Atual                                                                                                                                 |
| ----------------------------- | ----------------------------------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Roberto Carlos Meirelles      | Analista de Sistemas Sênior (Coordenador) | 1997–2010 | Aposentado (2010). Responsável pela arquitetura original e decisões de modelagem de dados.                                                     |
| Fernanda Cristina de Oliveira | Analista de Negócios                      | 1997–2012 | Aposentada (2012). Única pessoa que documentou parcialmente as regras de negócio. Autora do "RN-SIFAP-2012-parcial.doc".                       |
| Marcos Antônio Ferreira       | Programador Natural Sênior                | 2001–2017 | Transferido para SUPDE/DESIN (2017). Último desenvolvedor com conhecimento integral do código. Implementou CALCDSCT e as refatorações de 2005. |
| Cláudia Regina dos Santos     | DBA Adabas                                | 1997–2008 | Aposentada (2008). Projetou os 4 DDMs e as rotinas de backup/recovery.                                                                         |
| José Aparecido Lima           | Programador Natural                       | 1997–2005 | Aposentado (2005). Responsável pelos módulos batch originais.                                                                                  |
| Patrícia Helena Moura         | Analista de Sistemas                      | 2003–2016 | Transferida para SUPDE/DEGED (2016). Trabalhou na integração SIAFI e no módulo de auditoria.                                                   |
| Antônio Carlos Ribeiro        | Analista de Suporte / Operação            | 1999–2014 | Aposentado (2014). Conhecimento operacional do agendamento batch e monitoração.                                                                |
| Luciana Barbosa de Freitas    | Programador Natural Júnior                | 2010–2018 | Em exercício na SUPDE/DESIF. Única remanescente com algum conhecimento do sistema, porém limitado aos módulos de consulta.                     |

> **ALERTA:** O conhecimento técnico detalhado das regras de cálculo (CALCBENF, CALCCORR, CALCDSCT) reside **exclusivamente no código-fonte**. Não há documentação funcional atualizada desses módulos.

---

## 4. Arquitetura do Sistema

### 4.1. Visão Geral

```
┌─────────────────────────────────────────────────────────────┐
│ MAINFRAME a organização │
│ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ NATURAL 6.3 │ │ ADABAS 7.4 │ │ JOB SCHED. │ │
│ │ │ │ │ │ (JES2/CICS) │ │
│ │ Programas │◄──►│ DDMs (4) │ │ │ │
│ │ Online (8) │ │ FDTs │ │ Jobs Batch │ │
│ │ Batch (7) │ │ │ │ (7 procs) │ │
│ └──────┬───────┘ └──────────────┘ └──────┬───────┘ │
│ │ │ │
│ ▼ ▼ │
│ ┌──────────────┐ ┌──────────────┐ │
│ │ TELAS 3270 │ │ ARQUIVOS │ │
│ │ (Com*plete) │ │ CNAB / TXT │ │
│ └──────┬───────┘ └──────┬───────┘ │
│ │ │ │
└─────────┼───────────────────────────────────────┼───────────┘
 │ │
 ▼ ▼
 ┌──────────────┐ ┌──────────────────────────────┐
 │ TERMINAIS │ │ SISTEMAS EXTERNOS │
 │ EMULAÇÃO │ │ - SIAFI (STN) │
 │ 3270 │ │ - Receita Federal (CPF) │
 │ (Operadores │ │ - Banco do Brasil (CNAB) │
 │ CGPB) │ │ - CAIXA (arquivo retorno) │
 └──────────────┘ └──────────────────────────────┘
```

### 4.2. Camada de Programas Natural

Os programas Natural do SIFAP estão organizados na biblioteca **SIFAP** do Natural, subdivididos em:

- **Programas Online (interativos):** Executados via emulação de terminal 3270, utilizando maps (telas) Natural. Acessados pelos operadores da CGPB e DEFIS.
- **Programas Batch:** Executados por agendamento no scheduler JES2, com acionamento mensal (folha de pagamento) ou sob demanda (relatórios, conciliação).
- **Subprogramas e Copycode:** Rotinas utilitárias compartilhadas (validação de CPF, cálculo de dígito verificador, formatação de valores).

### 4.3. Base de Dados - DDMs Adabas

O SIFAP utiliza 4 DDMs (Data Definition Modules) no Adabas:

| DDM                 | Arquivo Adabas (FNR) | Descrição                                                                                                   | Registros (est. 2018)          |
| ------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------ |
| **BENEFICIARIO**    | FNR 150              | Cadastro de beneficiários - dados pessoais, documentação, endereço, situação cadastral, histórico de status | ~4.200.000                     |
| **PROGRAMA-SOCIAL** | FNR 151              | Cadastro de programas sociais - regras de elegibilidade, faixas de valores, parâmetros de cálculo           | ~45 (registros parametrizados) |
| **PAGAMENTO**       | FNR 152              | Registros de pagamento - valor bruto, descontos, valor líquido, data de crédito, banco pagador, status      | ~180.000.000                   |
| **AUDITORIA**       | FNR 153              | Log de auditoria - ações de usuários, alterações cadastrais, ocorrências de fiscalização                    | ~25.000.000                    |

**Observações sobre a modelagem:**

- Os nomes de campos seguem a **convenção abreviada dos anos 90** (ex.: `BN-NM-BENEF` = nome do beneficiário, `PG-VL-BRUTO` = valor bruto do pagamento, `AU-DT-OCORR` = data da ocorrência de auditoria).
- Campos de valor utilizam formato compactado (packed decimal).
- Não há integridade referencial gerenciada pelo Adabas - toda validação é feita nos programas Natural.
- O DDM PROGRAMA-SOCIAL contém campos do tipo MU (multiple value) e PE (periodic group) para armazenar faixas de valores por exercício.

### 4.4. Processamento Batch

O ciclo de processamento batch mensal segue a seguinte sequência:

1. **BATCHPGT** - Processamento principal da folha de pagamento (execução: 1o dia útil do mês, janela batch de 4h)
2. **BATCHCON** - Conciliação com arquivos de retorno do Banco do Brasil / CAIXA
3. **BATCHREL** - Geração de relatórios gerenciais pós-processamento

**Janela batch:** 22:00 às 06:00 (horário de Brasília)
**Tempo médio de execução do BATCHPGT:** 3h20min (referência: ciclo de fevereiro/2018)
**Volume mensal processado:** ~3.800.000 pagamentos

### 4.5. Interface com Operadores

As telas do SIFAP utilizam **maps Natural** no formato 3270 (24 linhas x 80 colunas), acessadas via emulador de terminal. A navegação é baseada em códigos de transação (ex.: `SF01` = cadastro de beneficiário, `SF05` = consulta, `SF10` = relatório de auditoria).

---

## 5. Inventário de Programas

### 5.1. Módulo de Cadastro

| Programa  | Descrição                                               | Autor          | Ano  | Últ. Alteração | Status   |
| --------- | ------------------------------------------------------- | -------------- | ---- | -------------- | -------- |
| CADBENEF  | Cad. beneficiários - inclusão, alteração, exclusão      | R. Meirelles   | 1997 | 2015           | Produção |
| CADDEPEND | Cad. dependentes vinculados ao beneficiário titular     | J. A. Lima     | 1998 | 2008           | Produção |
| CADPROG   | Cad. programas sociais - parâmetros e faixas de valores | F. C. Oliveira | 1997 | 2015           | Produção |

### 5.2. Módulo de Cálculo

| Programa | Descrição                                            | Autor          | Ano  | Últ. Alteração | Status   |
| -------- | ---------------------------------------------------- | -------------- | ---- | -------------- | -------- |
| CALCBENF | Cálc. valor do benefício - regras por programa/faixa | R. Meirelles   | 1998 | 2015           | Produção |
| CALCCORR | Cálc. correções e reajustes - índices anuais         | M. A. Ferreira | 2005 | 2015           | Produção |
| CALCDSCT | Cálc. descontos e deduções legais (consignações, IR) | M. A. Ferreira | 2015 | 2018           | Produção |

### 5.3. Módulo de Validação

| Programa | Descrição                                                | Autor          | Ano  | Últ. Alteração | Status   |
| -------- | -------------------------------------------------------- | -------------- | ---- | -------------- | -------- |
| VALBENEF | Valid. dados cadastrais do beneficiário (CPF, NIS)       | R. Meirelles   | 1997 | 2005           | Produção |
| VALELEG  | Valid. elegibilidade - cruzamento com regras do programa | F. C. Oliveira | 1999 | 2012           | Produção |
| VALDOCS  | Valid. documentação comprobatória - checklist por tipo   | P. H. Moura    | 2003 | 2008           | Produção |

### 5.4. Módulo Batch

| Programa | Descrição                                             | Autor       | Ano  | Últ. Alteração | Status   |
| -------- | ----------------------------------------------------- | ----------- | ---- | -------------- | -------- |
| BATCHPGT | Proc. folha de pagamento mensal - geração de créditos | J. A. Lima  | 1999 | 2018           | Produção |
| BATCHREL | Geração de relatórios batch (totalizadores, resumos)  | J. A. Lima  | 1999 | 2008           | Produção |
| BATCHCON | Conciliação financeira - retorno bancário x SIAFI     | P. H. Moura | 2002 | 2012           | Produção |

### 5.5. Módulo de Consulta e Relatório

| Programa | Descrição                                           | Autor          | Ano  | Últ. Alteração | Status   |
| -------- | --------------------------------------------------- | -------------- | ---- | -------------- | -------- |
| CONSBENF | Consulta beneficiário - tela 3270 com filtros       | R. Meirelles   | 1997 | 2005           | Produção |
| RELPGT   | Relatório de pagamentos - por período/programa/UF   | P. H. Moura    | 2003 | 2012           | Produção |
| RELAUDIT | Relatório de auditoria - ocorrências e divergências | M. A. Ferreira | 2005 | 2015           | Produção |

### 5.6. Subprogramas e Copycode (parcialmente documentados)

| Componente | Tipo        | Descrição                                        |
| ---------- | ----------- | ------------------------------------------------ |
| VALCPF     | Subprograma | Validação de CPF (dígito verificador)            |
| VALNISN    | Subprograma | Validação de NIS/NIT                             |
| FMTVLR     | Copycode    | Formatação de valores monetários                 |
| FMTDT      | Copycode    | Formatação e validação de datas                  |
| LOGAUDIT   | Subprograma | Gravação de registro de auditoria                |
| CALCIDX    | Subprograma | Aplicação de índice de correção (tabela interna) |

> **Nota:** Podem existir subprogramas adicionais não catalogados. O inventário acima reflete o levantamento realizado em 2008.

---

## 6. Volumes de Dados

### 6.1. Volumetria Atual (Referência: março/2018)

| Indicador                                     | Volume                 |
| --------------------------------------------- | ---------------------- |
| Beneficiários cadastrados (ativos + inativos) | ~4.200.000 registros   |
| Beneficiários ativos                          | ~3.850.000 registros   |
| Programas sociais parametrizados              | 45 programas           |
| Registros de pagamento (histórico completo)   | ~180.000.000 registros |
| Registros de auditoria                        | ~25.000.000 registros  |
| Pagamentos processados por ciclo mensal       | ~3.800.000             |
| Arquivo de remessa CNAB (mensal)              | ~380 MB                |
| Espaço total em disco Adabas (ASSO + DATA)    | ~120 GB                |

### 6.2. Picos de Processamento

- **Pico mensal:** Processamento da folha de pagamento - 1o dia útil de cada mês
- **Pico anual:** Reajuste de benefícios (janeiro) - reprocessamento completo com novos índices
- **Pico extraordinário:** Pagamentos complementares ou 13o benefício (quando autorizado por decreto)

### 6.3. Crescimento

O volume de registros na tabela PAGAMENTO cresce a uma taxa aproximada de **46 milhões de registros/ano** (3,8M x 12 meses + estornos e complementares). Não há política de expurgo implementada. Os registros mais antigos datam de **1998**.

---

## 7. Criticidade Operacional

### 7.1. Classificação

| Atributo                   | Valor                                                               |
| -------------------------- | ------------------------------------------------------------------- |
| **Nível de criticidade**   | **Nível 1 - Missão Crítica**                                        |
| **SLA de disponibilidade** | 99,5% (janela de manutenção excluída)                               |
| **Janela de manutenção**   | Domingos, 02:00–06:00                                               |
| **Famílias impactadas**    | ~4.000.000 de famílias em todo o território nacional                |
| **Plano de contingência**  | Processamento manual via planilhas (último recurso, nunca acionado) |

### 7.2. Impacto de Indisponibilidade

A indisponibilidade do SIFAP impacta diretamente:

- **Atraso no pagamento de benefícios** a famílias em situação de vulnerabilidade social;
- **Impossibilidade de consulta** pela rede de atendimento (CRAS, postos do MDAS);
- **Descumprimento de prazos legais** para crédito em conta;
- **Repercussão institucional** junto ao Ministério e à imprensa.

### 7.3. Registro de Incidentes Relevantes

| Data     | Incidente                                                        | Impacto                                    | Resolução                                                                                                              |
| -------- | ---------------------------------------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Mar/2016 | Timeout no BATCHPGT - ciclo com volume atípico (4,1M pagamentos) | Atraso de 18h na folha de pagamento        | Aumento de MAXTIME no JCL; otimização de leitura sequencial no FNR 152. Correção definitiva aplicada na v4.1.2 (2018). |
| Jan/2014 | Falha na conciliação SIAFI - divergência de totalizadores        | 3.200 pagamentos em duplicidade detectados | Correção manual + ajuste no BATCHCON para validação de hash totalizador.                                               |
| Set/2009 | Corrupção parcial do índice Adabas (FNR 150)                     | Sistema indisponível por 6h                | Recovery via ADASAV. Procedimento de backup revisado por Cláudia Regina dos Santos.                                    |

---

## 8. Sistemas Integrados

| Sistema                     | Órgão/Entidade                       | Tipo de Integração         | Descrição                                                                                                                                      |
| --------------------------- | ------------------------------------ | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **SIAFI**                   | Secretaria do Tesouro Nacional (STN) | Batch (arquivo TXT)        | Envio de ordens bancárias e recebimento de confirmações de pagamento. Conciliação mensal via BATCHCON.                                         |
| **CPF / Receita Federal**   | Receita Federal do Brasil            | Online (consulta)          | Validação de CPF na inclusão e atualização cadastral. Consulta via transação Natural com timeout de 30s.                                       |
| **Banco do Brasil**         | BB - Centralizador de Pagamentos     | Batch (arquivo CNAB 240)   | Remessa de créditos para pagamento em conta. Retorno com confirmações e rejeições.                                                             |
| **CAIXA Econômica Federal** | CAIXA - Pagamentos Sociais           | Batch (arquivo CNAB 240)   | Canal alternativo de pagamento para beneficiários com conta CAIXA. Integração adicionada em 2004.                                              |
| **CadÚnico**                | MDAS / SENARC                        | Batch (arquivo posicional) | Recebimento periódico de atualizações cadastrais do Cadastro Único. Processamento via job específico (não catalogado no inventário principal). |

> **Nota:** A integração com o CadÚnico foi implementada de forma emergencial em 2006 e **não segue o padrão arquitetural** dos demais módulos. O programa responsável não consta no inventário oficial.

---

## 9. Observações Importantes

> **Este documento reflete o estado do conhecimento em março de 2018. Muitas das informações abaixo são alertas recorrentes da equipe de sustentação.**

### 9.1. Documentação Parcial e Desatualizada

- A documentação funcional cobre **apenas os módulos de cadastro** (esforço de 2008).
- O documento "RN-SIFAP-2012-parcial.doc" contém regras de negócio levantadas em 2012, mas está **incompleto** (47 páginas de um total estimado de 200+).
- Não existe documentação técnica dos programas de cálculo (CALCBENF, CALCCORR, CALCDSCT). As regras estão **exclusivamente no código-fonte**.
- Os comentários no código-fonte estão em português, porém são **esparsos e frequentemente desatualizados**.

### 9.2. Regras de Negócio no Código

- Diversas regras de negócio críticas foram implementadas diretamente nos programas Natural **sem documentação correspondente**.
- O programa CALCBENF contém aproximadamente **4.800 linhas** de código, com lógica condicional aninhada em até 7 níveis.
- Existem constantes "hardcoded" que representam parâmetros de cálculo cujo significado **não é evidente** sem conhecimento do contexto normativo da época.

### 9.3. Perda de Conhecimento

- Dos 8 membros da equipe original, **apenas 1 permanece** na DESIF (Luciana Barbosa de Freitas), com conhecimento limitado aos módulos de consulta.
- Marcos Antônio Ferreira (transferido em 2017) é o último profissional com conhecimento integral do sistema, porém não está mais alocado ao projeto.
- **Recomendação registrada em 2016 (não atendida):** realizar sessões de transferência de conhecimento antes das aposentadorias previstas.

### 9.4. Interdependências Não Documentadas

- Alguns programas utilizam **áreas de dados globais (GDA)** compartilhadas, cujas dependências não estão mapeadas.
- O subprograma LOGAUDIT é chamado por praticamente todos os programas, mas seu comportamento varia conforme parâmetros não documentados.
- A ordem de execução dos jobs batch é **crítica** e está registrada apenas no JCL de produção e na memória operacional da equipe.

### 9.5. Convenções de Nomenclatura

Os nomes de campos nos DDMs seguem a convenção abreviada típica dos anos 90:

| Prefixo | Entidade        | Exemplos                                 |
| ------- | --------------- | ---------------------------------------- |
| `BN-`   | Beneficiário    | `BN-NM-BENEF`, `BN-NR-CPF`, `BN-CD-SIT`  |
| `PS-`   | Programa Social | `PS-NM-PROG`, `PS-VL-MIN`, `PS-VL-MAX`   |
| `PG-`   | Pagamento       | `PG-VL-BRUTO`, `PG-VL-LIQ`, `PG-DT-CRED` |
| `AU-`   | Auditoria       | `AU-DT-OCORR`, `AU-CD-ACAO`, `AU-NR-USR` |

Nomes de campos são limitados a **20 caracteres** e utilizam abreviações padronizadas: `NM` (nome), `NR` (número), `CD` (código), `DT` (data), `VL` (valor), `QT` (quantidade), `SG` (sigla), `IN` (indicador).

---

## 10. Estrutura de Diretórios deste Cenário

```
02-cenario-sifap-legado/
├── README.md ← este documento
├── natural-programs/ ← Programas Natural (.NSN) - código-fonte
├── adabas-ddms/ ← DDMs (Data Definition Modules) - definições de dados
├── legacy-docs/ ← Documentação parcial original (2008/2012)
└── demo/ ← Demo terminal interativa (Estágio 1)
```

---

## 11. Referências Internas

- **Nota Técnica SUPDE/DESIF no 012/2016** - "Riscos de continuidade operacional do SIFAP" (documento reservado)
- **RN-SIFAP-2012-parcial.doc** - Regras de negócio parcialmente documentadas (Fernanda C. de Oliveira, 2012)
- **Manual de Operação Batch - SIFAP v3.0** (2005) - Desatualizado, não reflete alterações pós-2015
- **Plano de Contingência SIFAP** (2014) - Revisão pendente desde 2016

---

**Última Atualização:** Documento atualizado em 15/03/2018 por Carlos Eduardo Mendes - SUPDE/DESIF

---

## Navegação

> Esta pasta `01-arqueologia/legado-sifap/` está incluída dentro do kit do time. Quando você trabalha no repositório do time, os vizinhos são os guias de estágio, não o catálogo do workshop.

| Anterior                                                  | Início                   | Próximo                                              |
| --------------------------------------------------------- | ------------------------ | ---------------------------------------------------- |
| [Estágio 1 — Guia de Arqueologia](../GUIDE.md) | [Kit do Time](../README.md) | [Estágio 2 — Spec Moderna](../../02-spec-moderna/GUIDE.md) |

## Documentos Relacionados

- [`01-arqueologia/LEGACY-EXPLORATION-CHECKLIST.md`](../LEGACY-EXPLORATION-CHECKLIST.md) — PORTÃO DURO: o que você precisa entregar antes de abrir o Estágio 2
- [`01-arqueologia/GUIDE.md`](../GUIDE.md) — passo a passo para ler este legado
- [`02-spec-moderna/GUIDE.md`](../../02-spec-moderna/GUIDE.md) — próximo passo: especificação moderna (EARS) com `source_legacy:` apontando para arquivos desta pasta


---

### Continuar a leitura

<table width="100%">
<tr>
<td width="50%" valign="top" align="left">
<sub><strong>← ANTERIOR</strong></sub><br/>
<a href="../GUIDE.md"><strong>GUIDE do Estágio 1</strong></a><br/>
<sub>Passo a passo do estágio.</sub>
</td>
<td width="50%" valign="top" align="right">
<sub><strong>PRÓXIMO →</strong></sub><br/>
<a href="COMO-LER-NATURAL.md"><strong>Como ler Natural</strong></a><br/>
<sub>Sintaxe explicada para não-devs.</sub>
</td>
</tr>
</table>

<sub>↑ <a href="../../README.md">Voltar ao Kit PT-BR</a></sub>

