---
title: "Regras de Negócio do SIFAP - Levantamento Parcial"
author: "Ana Cristina Barros - Analista de Negócio da SENARC"
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

> [!NOTE]
> Este é um documento histórico reconstituído para o exercício de arqueologia da imersão SIFAP 2.0. Ele simula o levantamento parcial de regras de negócio realizado em 2012 pela equipe da SENARC/CGPB. A linguagem da época, os nomes de pessoas, as incertezas e as lacunas documentadas foram preservados intencionalmente. **Este documento não deve ser usado como especificação atual do sistema.** Regras marcadas como `[PENDENTE]`, comentários sobre inconsistências e itens não verificados fazem parte do exercício: representam o desafio real de extração de conhecimento que a equipe deve enfrentar durante a arqueologia.

<!-- ====================================================================== -->
<!-- REGRAS DE NEGÓCIO DO SIFAP - LEVANTAMENTO PARCIAL -->
<!-- Sistema de Fiscalização e Administração de Pagamentos -->
<!-- SENARC - Secretaria Nacional de Renda de Cidadania -->
<!-- Em colaboração com a SUPDE/DESIF (a organização) -->
<!-- ====================================================================== -->

# REGRAS DE NEGÓCIO DO SIFAP - LEVANTAMENTO PARCIAL

**SISTEMA DE FISCALIZAÇÃO E ADMINISTRAÇÃO DE PAGAMENTOS**

---

|                        |                              |
| ---------------------- | ---------------------------- |
| **Documento:** | RN-SIFAP-2012-parcial |
| **Classificação:** | RESTRITO |
| **Data de emissão:** | 14/08/2012 |
| **Situação:** | RASCUNHO - INCOMPLETO |
| **Responsável:** | Ana Cristina Barros - SENARC |
| **Validação técnica:** | Pendente |

---

> **DOCUMENTO EM ELABORAÇÃO**
>
> Levantamento iniciado em junho/2012 e interrompido em agosto/2012 devido à indisponibilidade da equipe técnica. A aposentadoria do Sr. Roberto Carlos Meirelles (analista sênior, aposentado desde 2010) e a saída da Sra. Fernanda Oliveira (analista de negócio, aposentada em 2012) comprometeram significativamente a continuidade deste trabalho.
>
> As regras documentadas abaixo representam um **levantamento parcial**, baseado em:
>
> - Entrevistas com Marcos Antônio Ferreira (programador Natural sênior);
> - Análise parcial do código-fonte dos programas CADBENEF, CALCBENF e VALELEG;
> - Documentação existente (Manual Técnico SIFAP v2.3.1, 2008);
> - Conhecimento institucional da equipe SENARC/CGPB.
>
> **Este documento NÃO foi validado pela equipe técnica da organização e pode conter imprecisões.**

---

## 1. Cadastro de beneficiários

### 1.1. Regras de inclusão

**RN-001** - Todo beneficiário deve ter CPF válido (validação por dígito verificador, subprograma VALCPF) e NIS/NIT ativo (validação pelo subprograma VALNISN).

**RN-002** - Não é permitida a inclusão de beneficiário com CPF já existente no cadastro em situação ativa (BN-CD-SIT = 'A'). Beneficiários excluídos logicamente (BN-CD-SIT = 'E') podem ser reincluídos mediante novo cadastro.

**RN-003** - O beneficiário deve estar vinculado a pelo menos um programa social ativo (campo BN-CD-PROG referenciando cadastro válido no DDM SOCPROG com PS-IN-ATIVO = 'S').

**RN-004** - O número máximo de dependentes por beneficiário é **3** (campo BN-QT-DEPEND, valores de 0 a 3). Para programas que exijam número maior, solicite autorização à CGPB pelo formulário FR-SIFAP-012.

<!-- NOTA: Verificar com Marcos Antônio. Há indícios no código de que o
 limite foi alterado para 5 durante uma atualização de manutenção recente,
 mas não foi possível confirmar. O Manual Técnico v2.3 (2008) também registra 3. -->

**RN-005** - O campo de região (BN-CD-REGIAO) deve corresponder a uma região válida segundo a tabela interna do SIFAP (valores 01 a 27, correspondentes aos estados brasileiros e ao Distrito Federal). O valor 99 é reservado para uso interno.

<!-- NOTA: O valor 99 no campo BN-CD-REGIAO aparece em diversos registros
 na base de produção, mas não foi possível identificar sua finalidade.
 Marcos Antônio disse que "é o bypass do Roberto", mas não soube fornecer
 detalhes. Revisar o código do CADBENEF. -->

**RN-006** - A data de nascimento (BN-DT-NASC) é obrigatória. Beneficiários com menos de 16 anos na data da inclusão não são aceitos, exceto como dependentes.

**RN-007** - Os dados bancários (banco, agência, conta) são obrigatórios para beneficiários ativos. O SIFAP valida o código do banco em uma tabela interna (última atualização: 2011).

### 1.2. Regras de alteração

**RN-008** - [PENDENTE] - Regras para alteração de dados bancários. Não foi possível acessar o código responsável durante o levantamento. Verificar com o Sr. Roberto Carlos (aposentado desde 2010).

**RN-009** - A alteração do CPF de um beneficiário exige autorização de nível 2 (perfil SUPERVISOR na GDA de sessão). O CPF anterior é mantido no campo BN-NR-CPF-ANT para fins de auditoria.

**RN-010** - Toda alteração cadastral gera registros automáticos de auditoria pelo subprograma LOGAUDIT (campos: usuário, data/hora, campo alterado, valor anterior e valor novo).

### 1.3. Regras de exclusão

**RN-011** - A exclusão de beneficiário é sempre lógica (BN-CD-SIT alterado de 'A' para 'E'). Não há exclusão física de registros no DDM BENEFIC, o arquivo de Beneficiários.

**RN-012** - O sistema bloqueia a exclusão de beneficiários com pagamentos pendentes (PG-CD-STATUS = 'P'). O operador deve aguardar a liquidação ou cancelar os pagamentos antes da exclusão.

---

## 2. Cálculo de benefícios

### 2.1. Fórmula básica de cálculo

**RN-013** - O valor mensal do benefício é calculado pela seguinte fórmula:

```
VALOR-BENEFICIO = VALOR-BASE(program, bracket) + (ACRESCIMO-DEPEND * QT-DEPEND)
```

Onde:

- `VALOR-BASE` é obtido do DDM SOCPROG conforme a faixa de renda declarada pelo beneficiário;
- `ACRESCIMO-DEPEND` é o valor adicional por dependente, definido pelo programa;
- `QT-DEPEND` é o número de dependentes ativos vinculados ao beneficiário titular.

**RN-014** - O valor do benefício é sempre arredondado para baixo nos centavos (truncamento, não arredondamento matemático). Exemplo: R$ 125,567 → R$ 125,56.

<!-- NOTA: A fórmula acima é a fórmula BÁSICA. Marcos Antônio mencionou que
 existem "pelo menos mais 3 variações" no código do CALCBENF, incluindo
 um cálculo especial para dezembro (13º benefício / abono de fim de ano)
 e um multiplicador chamado "FACTOR-K" que ele não soube explicar. Não foi
 possível validar essas informações com a equipe.

 A regra de cálculo proporcional para benefícios iniciados no meio do mês
 (pro rata) também não está documentada. -->

### 2.2. Faixas de valores

**RN-017** - As faixas de valores são parametrizadas no DDM SOCPROG, usando campos PE (grupo periódico) indexados por exercício fiscal. Cada programa social pode ter até 10 faixas de valores definidas.

**RN-018** - A faixa aplicável ao beneficiário é determinada pela renda familiar per capita declarada (campo BN-VL-RENDA-PC). A atribuição segue a ordem crescente de renda e aplica a primeira faixa cujo limite superior seja maior ou igual à renda declarada.

### 2.3. Reajustes e correções

**RN-019** - O reajuste anual do benefício é aplicado em janeiro de cada ano, com base em índice definido por decreto presidencial. O índice é cadastrado na tabela interna do subprograma CALCIDX.

**RN-020** - O reajuste é aplicado ao VALOR-BASE, não ao valor total do benefício (incluindo o acréscimo por dependente). Revisar o código, pois isso não pôde ser validado com a equipe.

---

## 3. Descontos e deduções

> **Observação:** este módulo foi implementado em 2015 (programa CALCDSCT) e não fazia parte da versão 2.3.1 do sistema, coberta pelo Manual Técnico de 2008. As regras abaixo foram obtidas em entrevista com Marcos Antônio Ferreira, responsável pela implementação do módulo.

**RN-021** - O total de descontos aplicável a um benefício não pode exceder **30% do valor bruto**. Descontos acima desse limite são rejeitados, e o benefício é processado sem descontos, com geração de auditoria.

<!-- NOTA: Marcos Antônio mencionou que existe uma exceção para retenções
 determinadas judicialmente (ordens de penhora ou bloqueio), que podem
 ultrapassar o limite de 30%. Não foi possível confirmar isso no código,
 pois o acesso ao programa CALCDSCT é restrito e a análise não foi
 concluída durante o levantamento. -->

**RN-022** - Os tipos de desconto previstos são:

| Código | Tipo de desconto | Observação |
| ------ | -------------------------------- | -------------------------------------------- |
| 01 | Consignação voluntária | Empréstimo consignado autorizado |
| 02 | Imposto de renda retido na fonte | Conforme tabela vigente da Receita Federal |
| 03 | Contribuição previdenciária | Quando aplicável |
| 04 | Ressarcimento ao erário | Pagamento indevido identificado em auditoria |
| 05 | [A COMPLETAR] | Marcos Antônio mencionou "mais 2 ou 3 tipos" |

**RN-023** - A ordem de aplicação dos descontos segue a prioridade numérica do código (01 primeiro, depois 02 etc.). Quando o limite de 30% é atingido, os descontos de menor prioridade são descartados.

---

## 4. Elegibilidade

### 4.1. Regras básicas de elegibilidade

**RN-015** - [PENDENTE] - Regras detalhadas de elegibilidade por programa. A equipe SENARC/CGPB informou que as regras variam significativamente entre programas e que a documentação completa exigiria entrevistas com os gestores de cada programa. Levantamento não realizado por falta de agenda.

**RN-016** - [PENDENTE] - Regras de cruzamento com o CadÚnico. A integração foi implementada em caráter emergencial em 2006, e o programa responsável não consta no inventário oficial do SIFAP. O código-fonte não foi localizado durante a pesquisa.

### 4.2. Regras documentadas (parcial)

As seguintes regras de elegibilidade foram identificadas no código do programa VALELEG:

- O beneficiário deve ter situação cadastral ativa (BN-CD-SIT = 'A');
- O beneficiário deve ter dados bancários válidos e completos;
- A renda familiar per capita declarada deve estar nas faixas definidas para o programa;
- O beneficiário não pode estar inscrito em mais de 2 programas sociais simultaneamente (campo BN-QT-PROG, máximo = 2);
- A última atualização cadastral não pode ter ocorrido há mais de 24 meses (campo BN-DT-ULT-ATUAL);
- O beneficiário não pode ter ocorrência de auditoria não resolvida do tipo 'B' (bloqueante) no DDM AUDIT.

> **Observação:** as regras acima foram extraídas pela leitura do código-fonte de VALELEG e podem não representar todas as verificações realizadas. O programa tem aproximadamente 1.200 linhas de código com lógica condicional complexa.

<!-- NOTA: A regra de bypass da região 99 não está documentada.
 Durante a análise de VALELEG, foi identificado um trecho de código
 que ignora toda a validação de elegibilidade quando BN-CD-REGIAO = 99.
 Marcos Antônio não soube explicar a origem dessa regra. Suspeita-se
 que seja um mecanismo de teste implementado ou um bypass administrativo
 criado pelo Sr. Roberto Carlos. Requer investigação. -->

---

## 5. Batch de pagamentos

### 5.1. Processamento mensal

O processamento batch mensal (programa BATCHPGT) segue estas regras:

- O processamento começa no 1º dia útil de cada mês, às 22:00;
- Todos os beneficiários ativos (BN-CD-SIT = 'A') são processados;
- O processamento ocorre em **ordenação padrão** (conforme o descritor do arquivo Adabas);
- Para cada beneficiário, o valor do benefício é recalculado pela invocação de CALCBENF;
- Após o cálculo, os descontos são aplicados pela invocação de CALCDSCT (a partir da versão 4.0);
- O registro de pagamento é gravado no DDM PAYMENT com situação 'P' (pendente);
- Ao fim do processamento, o arquivo de remessa CNAB 240 é gerado.

<!-- NOTA: A "ordenação padrão" mencionada acima é, na prática, a ordenação
 alfabética pelo nome do beneficiário (campo BN-NM-BENEF), que é o
 descritor principal do arquivo Adabas FNR 150. Essa ordenação é um
 artefato da modelagem original de 1997 e não tem significado funcional.
 No entanto, alterar a ordem de processamento pode causar divergências
 nos totalizadores de controle, pois o programa usa acumuladores por
 faixa alfabética parcial. -->

### 5.2. Tratamento de erros

- Erros de cálculo de um beneficiário individual não interrompem o processamento;
- Beneficiários com erro são marcados com situação 'E' (erro) no DDM PAYMENT;
- Um relatório de erros é gerado ao fim do processamento;
- Se a quantidade de erros exceder o parâmetro MAX-ERROS (padrão: 100), o processamento é interrompido com ABEND U4038;
- [A COMPLETAR] - Documentar o procedimento de reprocessamento de beneficiários com erro.

---

## 6. Regras pendentes de levantamento

As seguintes áreas de regras de negócio **não foram documentadas** neste levantamento:

| Área | Motivo | Prioridade estimada |
| ------------------------------------------- | ------------------------------------------------------------ | ------------------- |
| Cálculo do 13º benefício (abono de Natal) | Não foi possível acessar a rotina específica no CALCBENF | Alta |
| Fator K (multiplicador de cálculo) | Marcos Antônio não soube explicar; exige análise do código | Alta |
| Regras de conciliação financeira (BATCHCON) | Patrícia Helena Moura (responsável) foi transferida para a DEGED | Média |
| Integração com CadÚnico | Programa não catalogado; código-fonte não encontrado | Média |
| Regras de auditoria (RELAUDIT) | Módulo fora do escopo inicial deste levantamento | Média |
| Cálculo proporcional (pro rata) | Mencionado por Marcos Antônio, sem detalhamento | Alta |
| Exceção judicial ao limite de desconto | Mencionada por Marcos Antônio, não confirmada no código | Alta |
| Bypass de elegibilidade da região 99 | Identificado no código, sem explicação conhecida | Alta |
| Regras de desvinculação de dependentes | Não documentadas | Baixa |
| Procedimentos de rollback e reprocessamento | Referenciados no Manual ITSM-SIFAP vol. 3 (nunca concluído) | Alta |

---

## 7. Matriz de regras - Resumo

| ID | Módulo | Regra (resumo) | Situação | Observação |
| ------ | ------------- | ------------------------------------------- | ------------ | ---------------------------------------------- |
| RN-001 | Cadastro | CPF e NIS obrigatórios e válidos | Documentada | - |
| RN-002 | Cadastro | CPF único para beneficiário ativo | Documentada | - |
| RN-003 | Cadastro | Vínculo obrigatório com programa social | Documentada | - |
| RN-004 | Cadastro | Máximo de 3 dependentes | Documentada | **Possivelmente desatualizada, verificar o código** |
| RN-005 | Cadastro | Região válida (01-27) + 99 reservado | Documentada | Significado de 99 desconhecido |
| RN-006 | Cadastro | Idade mínima de 16 anos | Documentada | - |
| RN-007 | Cadastro | Dados bancários obrigatórios | Documentada | Tabela de bancos desatualizada (2011) |
| RN-008 | Cadastro | Alteração de dados bancários | **PENDENTE** | Não levantada |
| RN-009 | Cadastro | Alteração de CPF, nível SUPERVISOR | Documentada | - |
| RN-010 | Cadastro | Auditoria automática das alterações | Documentada | - |
| RN-011 | Cadastro | Exclusão sempre lógica | Documentada | - |
| RN-012 | Cadastro | Bloqueio de exclusão com pagamento pendente | Documentada | - |
| RN-013 | Cálculo | Fórmula básica do benefício | Documentada | **Fórmula parcial, faltam variações** |
| RN-014 | Cálculo | Arredondamento por truncamento | Documentada | - |
| RN-015 | Elegibilidade | Regras detalhadas por programa | **PENDENTE** | Falta de agenda da SENARC |
| RN-016 | Elegibilidade | Cruzamento com CadÚnico | **PENDENTE** | Programa não encontrado |
| RN-017 | Cálculo | Faixas de valores parametrizadas | Documentada | - |
| RN-018 | Cálculo | Atribuição de faixa por renda | Documentada | - |
| RN-019 | Cálculo | Reajuste anual em janeiro | Documentada | - |
| RN-020 | Cálculo | Reajuste sobre o valor-base | Documentada | **Não validada com a equipe técnica** |
| RN-021 | Descontos | Limite de 30% do valor bruto | Documentada | **Exceção judicial não documentada** |
| RN-022 | Descontos | Tipos de desconto | Documentada | Lista incompleta |
| RN-023 | Descontos | Ordem de prioridade dos descontos | Documentada | - |

---

## 8. Considerações finais

Este levantamento foi interrompido prematuramente e representa, na melhor hipótese, **cerca de 25% das regras de negócio do SIFAP**. As regras mais críticas e complexas, cálculo do 13º benefício, fator K, exceções judiciais e bypass de elegibilidade, continuam **não documentadas** e existem apenas no código-fonte Natural.

A continuidade deste trabalho depende de:

1. Disponibilidade de Marcos Antônio Ferreira (último analista com conhecimento completo do sistema) para sessões de transferência de conhecimento;
2. Acesso ao código-fonte dos programas CALCBENF, CALCDSCT e VALELEG em ambiente de homologação;
3. Apoio da CGPB para validar as regras com os gestores dos programas sociais;
4. Priorização formal pela CGTI/MDAS, pois este levantamento não consta no plano de trabalho atual.

**Recomendação:** caso este levantamento não seja retomado em curto prazo, recomenda-se investigar diretamente no código-fonte pelo menos as regras marcadas como "Alta prioridade" na seção 6, antes que o Sr. Marcos Antônio Ferreira seja transferido ou se aposente.

<!-- Esta recomendação não foi atendida. Marcos Antônio foi transferido
 para a SUPDE/DESIN em 2017. -->

---

**Elaboração:** Ana Cristina Barros - Analista de Negócio - SENARC/CGPB

**Colaboração técnica:** Marcos Antônio Ferreira - Programador Natural Sênior - SUPDE/DESIF

**Validação:** Pendente

**Aprovação:** Pendente

---

**Documento interno da organização/SENARC - Classificação: RESTRITO - Reprodução proibida**

---

[Voltar ao cenário legado](../README.md)
