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
| `BENEFICIARIO.ddm` | DBID 057 / FNR 150 | Cadastro de beneficiários — dados pessoais, documentos, situação cadastral, dados bancários, dependentes (PE) |
| `PAGAMENTO.ddm` | DBID 057 / FNR 152 | Registros de pagamento — valores, datas, status, banco pagador, descontos (PE), conciliação |
| `PROGRAMA-SOCIAL.ddm` | DBID 057 / FNR 151 | Programas sociais — regras de elegibilidade, faixas de valores, parâmetros de cálculo |
| `AUDITORIA.ddm` | DBID 057 / FNR 153 | Trilha de auditoria — ações de usuários, alterações cadastrais, contexto batch |
| `FDT-150-BENEFICIARIO.txt` | DBID 057 / FNR 150 | **FDT físico** do arquivo 150 (saída ADAREP) — layout real, opções `NU`/`FI`/`DE`/`UQ`, volumetria e estimativa de janela de unload |

---

## Como ler um DDM

Os arquivos `.ddm` deste diretório são **listagens** geradas pelo utilitário `LISTDDM` do SYSDDM — ou seja, saída de máquina, não fonte editável. A tabela central tem sempre as mesmas 8 colunas:

```text
 T L DB Name                     F Leng  S D Remark
 - - -- ------------------------ - ----  - - ---------------------------
   1 AB NUM-CPF                  A   11    U CPF SEM FORMATACAO
 P 1 DA GRP-DEPENDENTE                        (1:10) GRUPO PERIODICO
 S   S2 SUPER-UF-SIT             A    3    S
        /* BG(1-2), CE(1-1)
```

| Coluna | Significado | Valores possíveis |
|---|---|---|
| **T** | Tipo da entrada | *(branco)* = campo elementar · `G` = grupo · `M` = multiple-value (`MU`) · `P` = periodic group (`PE`) · `S` = descritor derivado |
| **L** | Nível | `1` = campo raiz · `2` = campo dentro de um grupo ou PE. Descritores derivados não têm nível |
| **DB** | *Short name* | Nome físico de **2 bytes** no FDT. É o único nome que o arquivo Adabas realmente conhece |
| **Name** | Nome longo | Só existe no DDM. É o nome que os programas Natural usam nas `VIEW OF` |
| **F** | Formato | `A` = alfanumérico · `N` = numérico *unpacked* (1 byte por dígito) · `P` = *packed decimal* (2 dígitos por byte) |
| **Leng** | Comprimento | Bytes, ou `dígitos,decimais` para campos com casas decimais — **sempre com vírgula** (`9,2`, nunca `9.2`) |
| **S** | *Storage option* | `N` = *null suppression* (campo vazio não ocupa espaço nem entra no índice) · `F` = *fixed storage* (sem compressão, típico de indicadores de 1 byte) |
| **D** | Descritor | `D` = descriptor · `U` = unique descriptor · `S` = superdescriptor · `H` = hyperdescriptor · `P` = phonetic descriptor |
| **Remark** | Comentário | Domínio de valores, sentinelas, data de inclusão do campo. Ocorrências de `MU`/`PE` aparecem aqui como `(1:10)` |

Linhas iniciadas por `/*` logo abaixo de um descritor derivado listam **os campos que o compõem**. Por exemplo, `/* BG(1-2), CE(1-1)` significa "bytes 1-2 de `BG` concatenados com o byte 1 de `CE`".

> [!IMPORTANT]
> **`FIND ... WITH <campo>` e `READ ... BY <campo>` só são válidos se o campo tiver algo na coluna `D`.** Buscar por um campo não indexado é erro de runtime em Adabas, não erro de compilação — o programa "funciona" até rodar. Essa é a checagem nº 1 ao ler um programa `.NSN`.

### DDM × FDT

| | DDM (`.ddm`) | FDT (`FDT-150-BENEFICIARIO.txt`) |
|---|---|---|
| O que é | Visão **lógica** usada pelo Natural | Layout **físico** do arquivo no banco |
| Nomes | Longos (`NUM-CPF`) | Só *short names* (`AB`) |
| Gerado por | `LISTDDM` (SYSDDM) | `ADAREP` / `ADACMP` |
| Traz volumetria? | Estimativas no rodapé | Sim: `TOP-ISN`, `MAXISN`, taxa de compressão, extents, estimativa de unload |

Uma equipe real de migração recebe **os dois**. O DDM diz o que os campos significam; o FDT diz quanto a coisa pesa e quanto tempo leva para sair de lá.

### Armadilhas conhecidas neste corpus

- **Campos alfanuméricos usados como numéricos.** Vários campos são `A` no DDM e aparecem como `N` nos programas, inclusive em aritmética e como índice de array. Registro antigo com espaços em campo `A` gera erro no `MOVE` para `N`.
- **Sentinelas em vez de nulo.** `0` significando "sem prazo", `00000000000` como CPF placeholder, `99999999` como data indeterminada. Nenhum deles é `NULL`.
- **Campos órfãos.** Alguns campos existem no schema há décadas e nenhum dos 15 programas os lê ou escreve. Vale conferir antes de assumir que uma coluna carrega dado.
- **Domínios documentados no remark podem estar desatualizados.** O remark descreve o domínio *de quando o campo foi criado*, não necessariamente o que está gravado hoje.

---

## Como usar durante o Estágio 1

- [ ] **Abrir os DDMs relevantes à feature escolhida.** Nem sempre todos os 4 são necessários.
- [ ] **Ler a seção "Como ler um DDM" acima** antes de cruzar DDM com programa — sem as colunas `T`/`S`/`D` o cruzamento não faz sentido.
- [ ] **Identificar campos do tipo `MU` e `PE`** (coluna `T` = `M` ou `P`). São os que viram tabelas filhas no PostgreSQL.
- [ ] **Conferir a coluna `D` antes de aceitar um `FIND`/`READ BY`.** Se o campo não é descritor, o acesso é ilegal em Adabas.
- [ ] **Comparar cada `VIEW OF` com o DDM correspondente.** Nome, formato e comprimento precisam bater.
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
