<!-- markdownlint-disable MD013 MD025 MD026 MD028 MD029 MD034 MD040 MD051 MD060 -->

# Arquivos DDM Adabas

![LEGADO DDMs Adabas](https://img.shields.io/badge/LEGADO-DDMs%20Adabas-F25022?style=for-the-badge) ![ARQUIVOS 4 DDMs](https://img.shields.io/badge/ARQUIVOS-4%20DDMs-1A1A1A?style=for-the-badge)

> 🗺 **Você está aqui:** [Kit PT-BR](../../../README.md) → [Estágio 1](../../README.md) → [Legado](../README.md) → **Adabas DDMs**

> **Para quem é isto?** Para o time durante o Estágio 1, especialmente o Par 4 (DBA + QA) que lidera o mapeamento de DDMs → PostgreSQL.
>
> **O que você terá ao final desta leitura:** lista de DDMs disponíveis e como ler a estrutura FDT.


> Data Definition Modules que descrevem a estrutura física e lógica do banco Adabas usado pelo sistema SIFAP legado.

## Conteúdo

| Arquivo               | Descrição                                                        |
| --------------------- | ---------------------------------------------------------------- |
| `BENEFICIARIO.ddm`    | Registro mestre de beneficiário - dados pessoais, documentos, inscrição |
| `PAGAMENTO.ddm`       | Registro de transação de pagamento - valores, datas, status      |
| `PROGRAMA-SOCIAL.ddm` | Definições de programa social - regras, limites, elegibilidade   |
| `AUDITORIA.ddm`       | Trilha de auditoria - quem alterou o quê e quando                |

## Uso

Estes arquivos são **material de referência somente leitura** para os times do workshop durante o estágio de Arqueologia (Estágio 1). Mapeie cada campo DDM para um campo de entidade JPA no sistema modernizado.

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
<a href="../natural-programs/"><strong>Natural Programs</strong></a><br/>
<sub>Programas .NSN.</sub>
</td>
</tr>
</table>

<sub>↑ <a href="../../../README.md">Voltar ao Kit PT-BR</a></sub>

