---

title: "Documentação legada - SIFAP"
description: "Documentos técnicos históricos do sistema SIFAP original (1997–2012)"
author: "Paula Silva, Americas Software GBB, Microsoft"
date: "2026-04-23"
version: "1.0.0"
status: "aprovado"
tags: ["legado", "documentação", "sifap", "arquitetura", "história"]
---

# Documentação legada — SIFAP

> **Trilha:** [Kit do Time](../../../README.md) › [Estágio 1](../../README.md) › [Legado SIFAP](../README.md) › **Documentação legada**

**Documentos técnicos históricos do sistema SIFAP original, referentes ao período de 1997 a 2012.** Material de referência somente leitura para o exercício de arqueologia de software.

| Campo | Valor |
|---|---|
| **Público-alvo** | Todas as duplas durante o Estágio 1 |
| **Pré-requisitos** | Nenhum |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Compreensão do contexto histórico para comparação com o código-fonte |

> [!IMPORTANT]
> Os documentos desta pasta são **material de referência somente leitura**. Compare as regras de negócio documentadas aqui com os programas Natural para verificar sua validade atual. A documentação pode estar desatualizada em relação ao código de produção.

---

## Conteúdo

| Arquivo | Ano | Descrição |
|---|---|---|
| `ORIGINAL-ARCHITECTURE-1997.md` | 1997 | Documento de arquitetura técnica do projeto original, a visão planejada antes do início da codificação |
| `ORIGINAL-ARCHITECTURE-1997.docx` | 1997 | Formato original (Word) |
| `TECHNICAL-MANUAL-SIFAP-2008.md` | 2008 | Manual técnico de operações, abrange os módulos de cadastro e parte dos módulos de cálculo e batch |
| `TECHNICAL-MANUAL-SIFAP-2008.docx` | 2008 | Formato original (Word) |
| `BUSINESS-RULES-2012.md` | 2012 | Levantamento parcial de regras de negócio, interrompido; 47 páginas de um total estimado em mais de 200 |
| `BUSINESS-RULES-2012.docx` | 2012 | Formato original (Word) |

---

## Como usar estes documentos

Os arquivos `.md` são versões convertidas que facilitam a leitura no VS Code e no GitHub. Os arquivos `.docx` estão no formato original.

Ao ler os programas Natural, use estes documentos para:

1. **Confirmar** uma regra inferida do código. Se o comportamento coincidir com a documentação, classifique-o como `Confirmada` no catálogo.
2. **Contextualizar** decisões arquiteturais que parecem arbitrárias no código. A justificativa técnica ou regulatória costuma estar registrada aqui.
3. **Identificar lacunas** entre o que a documentação descreve e o código implementa, nos dois sentidos.

> [!WARNING]
> Os módulos de cálculo (`CALCBENF`, `CALCCORR`, `CALCDSCT`) **não têm documentação formal nesta pasta**. As regras desses programas existem exclusivamente no código-fonte. Não presuma que o comportamento atual coincide com a documentação de 2008.

---

### Continue lendo

| Anterior | Próximo |
|---|---|
| [Legado SIFAP, visão geral](../README.md)<br/><sub>Contexto do sistema e inventário completo.</sub> | [Estágio 1 — GUIDE](../../GUIDE.md)<br/><sub>Roteiro cronometrado de 90 minutos.</sub> |

<sub>[Voltar ao índice do kit](../../../README.md)</sub>
