<!-- markdownlint-disable MD013 MD025 MD026 MD028 MD029 MD034 MD040 MD051 MD060 -->

---
title: "Regras de Negócio do SIFAP - Levantamento Parcial"
author: "Ana Cristina Barros - Analista de Negócios SENARC"
date: "2012-08-14"
version: "1.0.0-DRAFT"
classification: "RESTRITO"
status: "INCOMPLETO - Levantamento interrompido"
distribution: "SENARC/CGPB, SUPDE/DESIF, CGTI/MDAS"
revision_history:
 - version: "0.1.0"
 date: "2012-06-04"
 author: "Ana Cristina Barros"
 description: "Início do levantamento - módulo de cadastro"
 - version: "0.5.0"
 date: "2012-07-10"
 author: "Ana Cristina Barros"
 description: "Inclusão parcial dos módulos de cálculo e descontos"
 - version: "1.0.0-DRAFT"
 date: "2012-08-14"
 author: "Ana Cristina Barros"
 description: "Última versão - levantamento interrompido"
---

<!-- markdownlint-disable MD013 MD025 MD026 MD028 MD029 MD034 MD040 MD051 MD060 -->

<!-- ====================================================================== -->
<!-- REGRAS DE NEGÓCIO DO SIFAP - LEVANTAMENTO PARCIAL -->
<!-- Sistema de Fiscalização e Administração de Pagamentos -->
<!-- SENARC - Secretaria Nacional de Renda de Cidadania -->
<!-- Em colaboração com SUPDE/DESIF (a organização) -->
<!-- ====================================================================== -->

# REGRAS DE NEGÓCIO DO SIFAP - LEVANTAMENTO PARCIAL

**SISTEMA DE FISCALIZAÇÃO E ADMINISTRAÇÃO DE PAGAMENTOS**

---

|                        |                              |
| ---------------------- | ---------------------------- |
| **Documento:**         | RN-SIFAP-2012-parcial        |
| **Classificação:**     | RESTRITO                     |
| **Data de emissão:**   | 14/08/2012                   |
| **Status:**            | RASCUNHO - INCOMPLETO        |
| **Responsável:**       | Ana Cristina Barros - SENARC |
| **Validação técnica:** | Pendente                     |

---

> **DOCUMENTO EM CONSTRUÇÃO**
>
> Levantamento iniciado em junho/2012, interrompido em agosto/2012 por falta de disponibilidade da equipe técnica. A aposentadoria do Sr. Roberto Carlos Meirelles (analista sênior, aposentado desde 2010) e a transferência da Sra. Fernanda Oliveira (analista de negócios, aposentada em 2012) comprometeram significativamente a continuidade deste trabalho.
>
> As regras documentadas abaixo representam **levantamento parcial**, baseado em:
>
> - Entrevistas com Marcos Antônio Ferreira (programador Natural sênior);
> - Análise parcial do código-fonte dos programas CADBENEF, CALCBENF e VALELEG;
> - Documentação existente (Manual Técnico SIFAP v2.3.1, 2008);
> - Conhecimento institucional da equipe SENARC/CGPB.
>
> **Este documento NÃO foi validado pela equipe técnica do a organização e pode conter imprecisões.**

---

## 1. Cadastro de Beneficiários

### 1.1. Regras de Inclusão

**RN-001** - Todo beneficiário deve possuir CPF válido (validação por dígito verificador - subprograma VALCPF) e NIS/NIT ativo (validação via subprograma VALNISN).

**RN-002** - Não é permitida a inclusão de beneficiário com CPF já existente no cadastro em situação ativa (BN-CD-SIT = 'A'). Beneficiários excluídos logicamente (BN-CD-SIT = 'E') podem ser reincluídos mediante novo cadastro.

**RN-003** - O beneficiário deve estar vinculado a pelo menos um programa social ativo (campo BN-CD-PROG referenciando registro válido no DDM PROGRAMA-SOCIAL com PS-IN-ATIVO = 'S').

**RN-004** - O número máximo de dependentes por beneficiário titular é **3** (campo BN-QT-DEPEND, valores de 0 a 3). Para programas que exijam número superior, solicitar autorização da CGPB via formulário FR-SIFAP-012.

<!-- NOTA: Conferir com Marcos Antônio - há indícios no código de que o
 limite foi alterado para 5 em alguma manutenção recente, mas não
 conseguimos confirmar. O Manual Técnico v2.3 (2008) também registra 3. -->

**RN-005** - O campo de região (BN-CD-REGIAO) deve corresponder a uma região válida conforme tabela interna do SIFAP (valores 01 a 27, correspondendo às UFs). O valor 99 é reservado para uso interno.

<!-- NOTA: O valor 99 no campo BN-CD-REGIAO aparece em diversos registros
 na base de produção, mas não conseguimos identificar sua finalidade.
 Marcos Antônio mencionou que "é um bypass do Roberto" mas não soube
 detalhar. Consultar código CADBENEF. -->

**RN-006** - Data de nascimento (BN-DT-NASC) é campo obrigatório. Não são aceitos beneficiários com idade inferior a 16 anos na data de inclusão, exceto como dependentes.

**RN-007** - Dados bancários (banco, agência, conta) são obrigatórios para beneficiários ativos. O SIFAP valida o código do banco contra tabela interna (última atualização: 2011).

### 1.2. Regras de Alteração

**RN-008** - [PENDENTE] - Regras de alteração de dados bancários. Não foi possível acessar o código responsável durante o período do levantamento. Conferir com Sr. Roberto Carlos (aposentado desde 2010).

**RN-009** - A alteração de CPF de um beneficiário exige autorização nível 2 (perfil SUPERVISOR no GDA de sessão). O CPF antigo é mantido no campo BN-NR-CPF-ANT para fins de auditoria.

**RN-010** - Toda alteração cadastral gera registro de auditoria automático via subprograma LOGAUDIT (campos: usuário, data/hora, campo alterado, valor anterior, valor novo).

### 1.3. Regras de Exclusão

**RN-011** - A exclusão de beneficiário é sempre lógica (BN-CD-SIT alterado de 'A' para 'E'). Não há exclusão física de registros no DDM BENEFICIARIO.

**RN-012** - A exclusão de beneficiário com pagamentos pendentes (PG-CD-STATUS = 'P') é bloqueada pelo sistema. O operador deve aguardar a liquidação ou realizar o cancelamento dos pagamentos antes da exclusão.

---

## 2. Cálculo de Benefícios

### 2.1. Fórmula Básica de Cálculo

**RN-013** - O valor do benefício mensal é calculado pela seguinte fórmula:

```
VALOR-BENEFICIO = VALOR-BASE(programa, faixa) + (ACRESCIMO-DEPEND * QT-DEPEND)
```

Onde:

- `VALOR-BASE` é obtido do DDM PROGRAMA-SOCIAL conforme a faixa de renda declarada do beneficiário;
- `ACRESCIMO-DEPEND` é o valor adicional por dependente, definido por programa;
- `QT-DEPEND` é a quantidade de dependentes ativos vinculados ao beneficiário titular.

**RN-014** - O valor do benefício é sempre arredondado para baixo em centavos (truncamento, não arredondamento matemático). Exemplo: R$ 125,567 → R$ 125,56.

<!-- NOTA: A fórmula acima é a fórmula BÁSICA. Marcos Antônio mencionou que
 existem "pelo menos mais 3 variações" no código do CALCBENF, incluindo
 um cálculo especial para o mês de dezembro (13o benefício / abono
 natalino) e um fator multiplicador chamado "FATOR-K" que ele não
 soube explicar. Não foi possível validar com a equipe.

 Também não está documentada a regra de cálculo proporcional para
 benefícios com início no meio do mês (pro rata). -->

### 2.2. Faixas de Valores

**RN-017** - As faixas de valores são parametrizadas no DDM PROGRAMA-SOCIAL, utilizando campos PE (periodic group) indexados por exercício fiscal. Cada programa social pode ter até 10 faixas de valor definidas.

**RN-018** - A faixa aplicável ao beneficiário é determinada pela renda per capita familiar declarada (campo BN-VL-RENDA-PC). A atribuição de faixa segue ordem crescente de renda, sendo aplicada a primeira faixa cujo limite superior seja maior ou igual à renda declarada.

### 2.3. Reajustes e Correções

**RN-019** - O reajuste anual de benefícios é aplicado em janeiro de cada ano, mediante índice definido por decreto presidencial. O índice é registrado na tabela interna do subprograma CALCIDX.

**RN-020** - O reajuste é aplicado sobre o VALOR-BASE, não sobre o valor total do benefício (incluindo acréscimo por dependentes). Ver código - não foi possível validar com a equipe.

---

## 3. Descontos e Deduções

> **Nota:** Este módulo foi implementado em 2015 (programa CALCDSCT) e não constava na versão 2.3.1 do sistema coberta pelo Manual Técnico de 2008. As regras abaixo foram levantadas com base em entrevista com Marcos Antônio Ferreira, que implementou o módulo.

**RN-021** - O total de descontos aplicáveis a um benefício não pode exceder **30% do valor bruto**. Descontos que ultrapassem este limite são rejeitados, e o benefício é processado sem descontos, gerando ocorrência de auditoria.

<!-- NOTA: Marcos Antônio mencionou que existe uma exceção para retenções
 judiciais (ordens judiciais de penhora ou bloqueio), que podem
 ultrapassar o limite de 30%. Não foi possível confirmar no código,
 pois o programa CALCDSCT tem acesso restrito e a análise não foi
 concluída durante o levantamento. -->

**RN-022** - Os tipos de desconto previstos são:

| Código | Tipo de Desconto                 | Observação                                   |
| ------ | -------------------------------- | -------------------------------------------- |
| 01     | Consignação voluntária           | Empréstimo consignado autorizado             |
| 02     | Imposto de Renda retido na fonte | Conforme tabela vigente da Receita Federal   |
| 03     | Contribuição previdenciária      | Quando aplicável                             |
| 04     | Ressarcimento ao erário          | Pagamento indevido identificado em auditoria |
| 05     | [A COMPLETAR]                    | Marcos Antônio mencionou "mais 2 ou 3 tipos" |

**RN-023** - A ordem de aplicação dos descontos segue a prioridade numérica do código (01 primeiro, depois 02, etc.). Quando o limite de 30% é atingido, os descontos de menor prioridade são descartados.

---

## 4. Elegibilidade

### 4.1. Regras Básicas de Elegibilidade

**RN-015** - [PENDENTE] - Regras detalhadas de elegibilidade por programa. A equipe da SENARC/CGPB informou que as regras variam significativamente entre programas e que uma documentação completa exigiria entrevistas com os gestores de cada programa. Levantamento não realizado por falta de agenda.

**RN-016** - [PENDENTE] - Regras de cruzamento com CadÚnico. A integração com o CadÚnico foi implementada de forma emergencial em 2006 e o programa responsável não consta no inventário oficial do SIFAP. Não foi possível localizar o código-fonte durante o levantamento.

### 4.2. Regras Documentadas (parcial)

As seguintes regras de elegibilidade foram identificadas no código do programa VALELEG:

- Beneficiário deve estar com situação cadastral ativa (BN-CD-SIT = 'A');
- Beneficiário deve possuir dados bancários válidos e completos;
- A renda per capita familiar declarada deve estar dentro das faixas definidas para o programa;
- O beneficiário não pode estar inscrito em mais de 2 programas sociais simultaneamente (campo BN-QT-PROG, máximo = 2);
- A data de última atualização cadastral não pode ser superior a 24 meses (campo BN-DT-ULT-ATUAL);
- O beneficiário não pode possuir ocorrência de auditoria não resolvida do tipo 'B' (bloqueio) no DDM AUDITORIA.

> **Nota:** As regras acima foram extraídas por leitura do código-fonte do VALELEG e podem não representar a totalidade das verificações realizadas. O programa possui aproximadamente 1.200 linhas de código com lógica condicional complexa.

<!-- NOTA: Não está documentada a regra de bypass por região 99.
 Durante a análise do VALELEG, foi identificado um trecho de código
 que desvia toda a validação de elegibilidade quando BN-CD-REGIAO = 99.
 Marcos Antônio não soube explicar a origem desta regra. Suspeita-se
 que seja um mecanismo de teste ou bypass administrativo implementado
 pelo Sr. Roberto Carlos. Necessita investigação. -->

---

## 5. Batch de Pagamento

### 5.1. Processamento Mensal

O processamento batch mensal (programa BATCHPGT) segue as seguintes regras:

- O processamento é iniciado no 1o dia útil de cada mês, às 22:00h;
- Todos os beneficiários ativos (BN-CD-SIT = 'A') são processados;
- O processamento ocorre em **ordenação padrão** (conforme descritor do arquivo Adabas);
- Para cada beneficiário, o valor do benefício é recalculado invocando CALCBENF;
- Após o cálculo, os descontos são aplicados invocando CALCDSCT (a partir da versão 4.0);
- O registro de pagamento é gravado no DDM PAGAMENTO com status 'P' (pendente);
- Ao final do processamento, é gerado o arquivo de remessa CNAB 240.

<!-- NOTA: A "ordenação padrão" mencionada acima é, na prática, a ordenação
 alfabética pelo nome do beneficiário (campo BN-NM-BENEF), que é o
 descritor principal do arquivo Adabas FNR 150. Esta ordenação é um
 artefato da modelagem original de 1997 e não tem significado funcional.
 Porém, alterar a ordem de processamento poderia causar divergências
 nos totalizadores de controle, pois o programa utiliza acumuladores
 parciais por faixa alfabética. -->

### 5.2. Tratamento de Erros

- Erros de cálculo para um beneficiário individual não interrompem o processamento;
- Beneficiários com erro são marcados com status 'E' (erro) no DDM PAGAMENTO;
- Um relatório de erros é gerado ao final do processamento;
- Se o número de erros exceder o parâmetro MAX-ERROS (default: 100), o processamento é interrompido com ABEND U4038;
- [A COMPLETAR] - Documentar procedimento de reprocessamento de beneficiários com erro.

---

## 6. Regras Pendentes de Levantamento

As seguintes áreas de regras de negócio **não foram documentadas** neste levantamento:

| Área                                        | Motivo                                                       | Prioridade Estimada |
| ------------------------------------------- | ------------------------------------------------------------ | ------------------- |
| Cálculo do 13o benefício (abono natalino)   | Não foi possível acessar a rotina específica no CALCBENF     | Alta                |
| Fator K (multiplicador de cálculo)          | Marcos Antônio não soube explicar; precisa análise do código | Alta                |
| Regras de conciliação financeira (BATCHCON) | Patrícia Helena Moura (responsável) transferida para DEGED   | Média               |
| Integração com CadÚnico                     | Programa não catalogado; código-fonte não localizado         | Média               |
| Regras de auditoria (RELAUDIT)              | Módulo não coberto pelo escopo inicial deste levantamento    | Média               |
| Cálculo proporcional (pro rata)             | Mencionado por Marcos Antônio, não detalhado                 | Alta                |
| Exceção judicial ao limite de descontos     | Mencionado por Marcos Antônio, não confirmado no código      | Alta                |
| Bypass de elegibilidade por região 99       | Identificado no código, sem explicação conhecida             | Alta                |
| Regras de desvinculação de dependentes      | Não documentadas                                             | Baixa               |
| Procedimentos de rollback e reprocessamento | Remetido ao Manual ITSM-SIFAP vol. 3 (nunca concluído)       | Alta                |

---

## 7. Matriz de Regras - Resumo

| ID     | Módulo        | Regra (resumo)                              | Status       | Observação                                     |
| ------ | ------------- | ------------------------------------------- | ------------ | ---------------------------------------------- |
| RN-001 | Cadastro      | CPF e NIS obrigatórios e válidos            | Documentada  | -                                              |
| RN-002 | Cadastro      | CPF único para beneficiário ativo           | Documentada  | -                                              |
| RN-003 | Cadastro      | Vínculo obrigatório com programa social     | Documentada  | -                                              |
| RN-004 | Cadastro      | Máximo 3 dependentes                        | Documentada  | **Possível desatualização - verificar código** |
| RN-005 | Cadastro      | Região válida (01-27) + 99 reservado        | Documentada  | Significado do 99 desconhecido                 |
| RN-006 | Cadastro      | Idade mínima 16 anos                        | Documentada  | -                                              |
| RN-007 | Cadastro      | Dados bancários obrigatórios                | Documentada  | Tabela de bancos desatualizada (2011)          |
| RN-008 | Cadastro      | Alteração de dados bancários                | **PENDENTE** | Não levantada                                  |
| RN-009 | Cadastro      | Alteração de CPF - nível SUPERVISOR         | Documentada  | -                                              |
| RN-010 | Cadastro      | Auditoria automática em alterações          | Documentada  | -                                              |
| RN-011 | Cadastro      | Exclusão sempre lógica                      | Documentada  | -                                              |
| RN-012 | Cadastro      | Bloqueio de exclusão com pagamento pendente | Documentada  | -                                              |
| RN-013 | Cálculo       | Fórmula básica de benefício                 | Documentada  | **Fórmula parcial - faltam variações**         |
| RN-014 | Cálculo       | Arredondamento por truncamento              | Documentada  | -                                              |
| RN-015 | Elegibilidade | Regras detalhadas por programa              | **PENDENTE** | Falta de agenda SENARC                         |
| RN-016 | Elegibilidade | Cruzamento com CadÚnico                     | **PENDENTE** | Programa não localizado                        |
| RN-017 | Cálculo       | Faixas de valores parametrizadas            | Documentada  | -                                              |
| RN-018 | Cálculo       | Atribuição de faixa por renda               | Documentada  | -                                              |
| RN-019 | Cálculo       | Reajuste anual em janeiro                   | Documentada  | -                                              |
| RN-020 | Cálculo       | Reajuste sobre valor base                   | Documentada  | **Não validada com equipe técnica**            |
| RN-021 | Descontos     | Limite de 30% do valor bruto                | Documentada  | **Exceção judicial não documentada**           |
| RN-022 | Descontos     | Tipos de desconto                           | Documentada  | Lista incompleta                               |
| RN-023 | Descontos     | Ordem de prioridade de descontos            | Documentada  | -                                              |

---

## 8. Considerações Finais

Este levantamento foi interrompido prematuramente e representa, na melhor das estimativas, **cerca de 25% das regras de negócio do SIFAP**. As regras mais críticas e complexas - cálculo do 13o benefício, fator K, exceções judiciais, bypass de elegibilidade - permanecem **não documentadas** e existem apenas no código-fonte Natural.

A continuidade deste trabalho depende de:

1. Disponibilidade de Marcos Antônio Ferreira (último analista com conhecimento integral do sistema) para sessões de transferência de conhecimento;
2. Acesso ao código-fonte dos programas CALCBENF, CALCDSCT e VALELEG em ambiente de homologação;
3. Apoio da CGPB para validação das regras junto aos gestores dos programas sociais;
4. Priorização formal pela CGTI/MDAS, dado que este levantamento não consta no plano de trabalho vigente.

**Recomendação:** Caso este levantamento não seja retomado em curto prazo, sugere-se que ao menos as regras marcadas como "Alta prioridade" na seção 6 sejam investigadas diretamente no código-fonte, antes que o Sr. Marcos Antônio Ferreira seja transferido ou se aposente.

<!-- Esta recomendação não foi atendida. Marcos Antônio foi transferido
 para a SUPDE/DESIN em 2017. -->

---

**Elaboração:** Ana Cristina Barros - Analista de Negócios - SENARC/CGPB

**Colaboração técnica:** Marcos Antônio Ferreira - Programador Natural Sênior - SUPDE/DESIF

**Validação:** Pendente

**Aprovação:** Pendente

---

**Documento interno a organização/SENARC - Classificação: RESTRITO - Reprodução proibida**

---

[Voltar ao cenário legado](../README.md)
