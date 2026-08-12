<!-- markdownlint-disable MD013 MD033 MD041 -->

# Arquivos DDM Adabas

> **Trilha:** [Kit do Time](../../../README.md) › [Estágio 1](../../README.md) › [Legado SIFAP](../README.md) › **Adabas DDMs**

**DDMs (Data Definition Modules) do sistema SIFAP.** Descrevem a estrutura física e lógica do banco Adabas usado pelo legado. Material de referência para o Par 4 (DBA + QA) durante o Estágio 1.

| Campo | Valor |
|---|---|
| **Público-alvo** | Par 4 (DBA + QA) lidera; todos os pares consultam |
| **Pré-requisitos** | Leitura de [`COMO-LER-NATURAL.md`](../COMO-LER-NATURAL.md), seção 6 (tipos de campo) |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Mapeamento dos campos relevantes ao recorte escolhido |

---

## O que é um DDM

Um **DDM (Data Definition Module)** é o arquivo que descreve o schema de uma base de dados Adabas — equivalente a um `CREATE TABLE` do SQL. Cada DDM lista os campos (com tipo, tamanho e atributos como descritor ou multi-valor) de um arquivo Adabas (FNR).

**Por que importa:** sem ler o DDM você não sabe quais campos existem, quais tipos eles têm e quais estruturas (`MU`, `PE`) precisarão virar tabelas filhas no PostgreSQL. Os nomes de campo nos programas `.NSN` são abreviações que só fazem sentido quando cruzadas com o DDM.

**Como se aplica ao SIFAP:** o programa `CALCBENF.NSN` referencia campos como `BN-VL-RENDA-PC` e `PS-VL-MAX`. Para entender o que cada campo representa, consulte os DDMs `BENEFICIARIO` e `PROGRAMA-SOCIAL`.

---

## Conteúdo

| Arquivo | Arquivo Adabas | Descrição |
|---|---|---|
| `BENEFICIARIO.ddm` | FNR 150 | Cadastro de beneficiários — dados pessoais, documentos, situação cadastral, histórico de status |
| `PAGAMENTO.ddm` | FNR 152 | Registros de pagamento — valores, datas, status, banco pagador |
| `PROGRAMA-SOCIAL.ddm` | FNR 151 | Programas sociais — regras de elegibilidade, faixas de valores, parâmetros de cálculo |
| `AUDITORIA.ddm` | FNR 153 | Trilha de auditoria — ações de usuários, alterações cadastrais, ocorrências de fiscalização |

---

## Como usar durante o Estágio 1

- [ ] **Abrir os DDMs relevantes à feature escolhida.** Nem sempre todos os 4 são necessários.
- [ ] **Identificar campos do tipo `MU` e `PE`.** São os que viram tabelas filhas no PostgreSQL.
- [ ] **Registrar o mapeamento** no [`dependency-map.md`](../../dependency-map.md) (seção de arestas Programa → DDM).
- [ ] **Contribuir com termos** para o [`glossary.md`](../../glossary.md) — nomes de campos frequentemente revelam abreviações de domínio.

> [!WARNING]
> Estes arquivos são material de referência somente leitura. Não edite os DDMs.

---

### Continuar a leitura

| Anterior | Próximo |
|---|---|
| [Legado SIFAP — visão geral](../README.md)<br/><sub>Contexto do sistema e inventário completo.</sub> | [Programas Natural](../natural-programs/README.md)<br/><sub>Os 15 arquivos `.NSN` com lógica de negócio.</sub> |

<sub>[Voltar ao índice do kit](../../../README.md)</sub>
