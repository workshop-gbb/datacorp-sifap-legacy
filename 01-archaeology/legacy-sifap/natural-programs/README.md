<!-- markdownlint-disable MD013 MD033 MD041 -->

# Programas Natural

> **Trilha:** [Kit do Time](../../../README.md) › [Estágio 1](../../README.md) › [Legado SIFAP](../README.md) › **Programas Natural**

**Os 15 arquivos-fonte Natural do SIFAP.** Implementam toda a lógica de negócio do sistema legado. Cada par lê 3 programas durante o Estágio 1.

| Campo | Valor |
|---|---|
| **Público-alvo** | Todos os pares — cada par lê os 3 programas atribuídos |
| **Pré-requisitos** | Leitura de [`COMO-LER-NATURAL.md`](../COMO-LER-NATURAL.md) |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Regras catalogadas com evidência `arquivo.NSN#L<início>-L<fim>` |

> [!NOTE]
> Estes arquivos são material de referência somente leitura. Durante o Estágio 1, os pares analisam os programas para extrair regras de negócio e mapeá-las para o sistema moderno (Java 21 + Spring Boot).

---

## Distribuição por par

| Par | Programas |
|---|---|
| 1 · Visão (PO + RE) | `CADBENEF.NSN`, `CADDEPEND.NSN`, `CADPROG.NSN` |
| 2 · Arquitetura (EA + SA) | `BATCHPGT.NSN`, `BATCHREL.NSN`, `BATCHCON.NSN` |
| 3 · Implementação (TL + Dev) | `CALCBENF.NSN`, `CALCCORR.NSN`, `CALCDSCT.NSN` |
| 4 · Qualidade (DBA + QA) | `VALBENEF.NSN`, `VALDOCS.NSN`, `VALELEG.NSN` |
| 5 · Operações (DevOps + TW) | `CONSBENF.NSN`, `RELPGT.NSN`, `RELAUDIT.NSN` |

---

## Inventário completo por categoria

### Processamento Batch

| Programa | Autor | Ano | Descrição |
|---|---|---|---|
| `BATCHCON.NSN` | Patrícia H. Moura | 2002 | Conciliação batch — reconcilia pagamentos com o SIAFI |
| `BATCHPGT.NSN` | José A. Lima | 1999 | Pagamento batch — gera ciclos mensais de pagamento |
| `BATCHREL.NSN` | José A. Lima | 1999 | Relatório batch — produz relatórios gerenciais |

### Cadastro

| Programa | Autor | Ano | Descrição |
|---|---|---|---|
| `CADBENEF.NSN` | Roberto Meirelles | 1997 | Cadastro de beneficiário — inclusão, alteração, exclusão |
| `CADDEPEND.NSN` | José A. Lima | 1998 | Cadastro de dependente vinculado ao beneficiário titular |
| `CADPROG.NSN` | Fernanda C. Oliveira | 1997 | Cadastro de programa social — parâmetros e faixas de valores |

### Cálculo

| Programa | Autor | Ano | Descrição |
|---|---|---|---|
| `CALCBENF.NSN` | Roberto Meirelles | 1998 | Cálculo do valor do benefício por programa e faixa |
| `CALCCORR.NSN` | Marcos A. Ferreira | 2005 | Cálculo de correções e reajustes por índices anuais |
| `CALCDSCT.NSN` | Marcos A. Ferreira | 2015 | Cálculo de descontos e deduções legais (consignações, IR) |

### Validação

| Programa | Autor | Ano | Descrição |
|---|---|---|---|
| `VALBENEF.NSN` | Roberto Meirelles | 1997 | Validação de dados cadastrais (CPF, NIS) |
| `VALDOCS.NSN` | Patrícia H. Moura | 2003 | Validação de documentação comprobatória |
| `VALELEG.NSN` | Fernanda C. Oliveira | 1999 | Validação de elegibilidade — cruzamento com regras do programa |

### Consulta

| Programa | Autor | Ano | Descrição |
|---|---|---|---|
| `CONSBENF.NSN` | Roberto Meirelles | 1997 | Consulta de beneficiário por múltiplos critérios (tela 3270) |

### Relatórios

| Programa | Autor | Ano | Descrição |
|---|---|---|---|
| `RELAUDIT.NSN` | Marcos A. Ferreira | 2005 | Relatório de auditoria — ocorrências e divergências |
| `RELPGT.NSN` | Patrícia H. Moura | 2003 | Relatório de pagamentos por período, programa e UF |

---

### Continuar a leitura

| Anterior | Próximo |
|---|---|
| [Legado SIFAP — visão geral](../README.md)<br/><sub>Contexto do sistema e histórico.</sub> | [Adabas DDMs](../adabas-ddms/README.md)<br/><sub>Estruturas de dados Adabas.</sub> |

<sub>[Voltar ao índice do kit](../../../README.md)</sub>
