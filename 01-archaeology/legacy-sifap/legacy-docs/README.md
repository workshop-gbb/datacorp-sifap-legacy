<!-- markdownlint-disable MD013 MD033 MD041 -->

---
title: "Documentação Legada - SIFAP"
description: "Documentos técnicos históricos do sistema SIFAP original (1997–2012)"
author: "Paula Silva, Americas Software GBB, Microsoft"
date: "2026-04-23"
version: "1.0.0"
status: "approved"
tags: ["legacy", "documentation", "sifap", "architecture", "history"]
---

# Documentação Legada — SIFAP

> **Trilha:** [Kit do Time](../../../README.md) › [Estágio 1](../../README.md) › [Legado SIFAP](../README.md) › **Documentação Legada**

**Documentos técnicos históricos do sistema SIFAP original, cobrindo o período de 1997 a 2012.** Material de referência somente leitura para o exercício de arqueologia de software.

| Campo | Valor |
|---|---|
| **Público-alvo** | Todos os pares durante o Estágio 1 |
| **Pré-requisitos** | Nenhum |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Compreensão do contexto histórico para cruzamento com o código-fonte |

> [!IMPORTANT]
> Os documentos desta pasta são **material de referência somente leitura**. As regras de negócio documentadas aqui devem ser cruzadas com os programas Natural para verificação de validade atual — a documentação pode estar desatualizada em relação ao código em produção.

---

## Conteúdo

| Arquivo | Ano | Descrição |
|---|---|---|
| `ARQUITETURA-ORIGINAL-1997.md` | 1997 | Documento de arquitetura técnica do projeto original — visão planejada antes da codificação |
| `ARQUITETURA-ORIGINAL-1997.docx` | 1997 | Formato original (Word) |
| `MANUAL-TECNICO-SIFAP-2008.md` | 2008 | Manual técnico de operações — cobre módulos de cadastro e parte dos módulos de cálculo e batch |
| `MANUAL-TECNICO-SIFAP-2008.docx` | 2008 | Formato original (Word) |
| `REGRAS-NEGOCIO-2012.md` | 2012 | Levantamento parcial de regras de negócio — interrompido; 47 páginas de um total estimado de 200+ |
| `REGRAS-NEGOCIO-2012.docx` | 2012 | Formato original (Word) |

---

## Como usar estes documentos

Os arquivos `.md` são versões convertidas para facilitar a leitura no VS Code e no GitHub. Os arquivos `.docx` são o formato original.

Durante a leitura dos programas Natural, use estes documentos para:

1. **Confirmar** uma regra inferida do código — se o comportamento coincide com o descrito na documentação, classifique como `Confirmada` no catálogo.
2. **Contextualizar** decisões arquiteturais que parecem arbitrárias no código — frequentemente há justificativa técnica ou normativa registrada aqui.
3. **Identificar gaps** — o que a documentação descreve mas o código não implementa, e vice-versa.

> [!WARNING]
> Os módulos de cálculo (`CALCBENF`, `CALCCORR`, `CALCDSCT`) **não têm documentação formal nesta pasta**. As regras desses programas estão exclusivamente no código-fonte. Não assuma que o comportamento atual corresponde ao que a documentação de 2008 descreve.

---

### Continuar a leitura

| Anterior | Próximo |
|---|---|
| [Legado SIFAP — visão geral](../README.md)<br/><sub>Contexto do sistema e inventário completo.</sub> | [Estágio 1 — GUIDE](../../GUIDE.md)<br/><sub>Roteiro cronometrado de 90 min.</sub> |

<sub>[Voltar ao índice do kit](../../../README.md)</sub>
