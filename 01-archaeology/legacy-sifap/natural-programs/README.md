<!-- markdownlint-disable MD013 MD025 MD026 MD028 MD029 MD034 MD040 MD051 MD060 -->

# Programas Natural

![LEGADO Programas .NSN](https://img.shields.io/badge/LEGADO-Programas%20.NSN-F25022?style=for-the-badge) ![ARQUIVOS 15 programas](https://img.shields.io/badge/ARQUIVOS-15%20programas-1A1A1A?style=for-the-badge)

> 🗺 **Você está aqui:** [Kit PT-BR](../../../README.md) → [Estágio 1](../../README.md) → [Legado](../README.md) → **Natural Programs**

> **Para quem é isto?** Para o time durante o Estágio 1, lendo os 15 programas Natural.
>
> **O que você terá ao final desta leitura:** lista de programas, divisão por par (3 cada), e ponto de partida para leitura.


> Arquivos-fonte Natural (`.NSN`) que implementam a lógica de negócio legada do SIFAP no mainframe.

## Conteúdo

### Processamento Batch

| Programa       | Descrição                                           |
| -------------- | --------------------------------------------------- |
| `BATCHCON.NSN` | Conciliação batch - reconcilia pagamentos com o SIAFI |
| `BATCHPGT.NSN` | Pagamento batch - gera ciclos mensais de pagamento  |
| `BATCHREL.NSN` | Relatório batch - produz relatórios gerenciais      |

### Cadastro (CRUD)

| Programa        | Descrição                   |
| --------------- | --------------------------- |
| `CADBENEF.NSN`  | Cadastro de beneficiário    |
| `CADDEPEND.NSN` | Cadastro de dependente      |
| `CADPROG.NSN`   | Cadastro de programa social |

### Cálculo

| Programa       | Descrição                         |
| -------------- | --------------------------------- |
| `CALCBENF.NSN` | Cálculo do valor do benefício     |
| `CALCCORR.NSN` | Cálculo de correção/ajuste        |
| `CALCDSCT.NSN` | Cálculo de desconto               |

### Consulta

| Programa       | Descrição                |
| -------------- | ------------------------ |
| `CONSBENF.NSN` | Consulta de beneficiário |

### Validação

| Programa       | Descrição                    |
| -------------- | ---------------------------- |
| `VALBENEF.NSN` | Regras de validação de beneficiário |
| `VALDOCS.NSN`  | Validação de documentos      |
| `VALELEG.NSN`  | Validação de elegibilidade   |

### Relatórios

| Programa       | Descrição                 |
| -------------- | ------------------------- |
| `RELAUDIT.NSN` | Geração de relatório de auditoria |
| `RELPGT.NSN`   | Geração de relatório de pagamento |

## Uso

Estes arquivos são **material de referência somente leitura**. Durante o Estágio 1 (Arqueologia), os times analisam estes programas para extrair regras de negócio e mapeá-las para classes de serviço Java.

## Navegação

| Pai                                  | Início                            |
| ------------------------------------ | --------------------------------- |
| [02 - Cenário Legado](../README.md)  | [Raiz do Workspace](../../README.md) |


---

### Continuar a leitura

<table width="100%">
<tr>
<td width="50%" valign="top" align="left">
<sub><strong>← ANTERIOR</strong></sub><br/>
<a href="../README.md"><strong>Legado SIFAP</strong></a><br/>
<sub>Visão geral do legado.</sub>
</td>
<td width="50%" valign="top" align="right">
<sub><strong>PRÓXIMO →</strong></sub><br/>
<a href="../adabas-ddms/"><strong>Adabas DDMs</strong></a><br/>
<sub>DDMs Adabas.</sub>
</td>
</tr>
</table>

<sub>↑ <a href="../../../README.md">Voltar ao Kit PT-BR</a></sub>

