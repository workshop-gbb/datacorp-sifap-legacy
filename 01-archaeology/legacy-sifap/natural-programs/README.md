<!-- markdownlint-disable MD013 MD033 MD041 -->

# Programas Natural

> **Trilha:** [Kit do Time](../../../README.md) › [Estágio 1](../../README.md) › [Legado SIFAP](../README.md) › **Programas Natural**

**Os 15 programas Natural do SIFAP, mais os 9 membros de apoio da biblioteca.** Os programas implementam a lógica de negócio do sistema legado. Cada par lê 3 programas durante o Estágio 1.

| Campo | Valor |
|---|---|
| **Público-alvo** | Todos os pares — cada par lê os 3 programas atribuídos |
| **Pré-requisitos** | Leitura de [`COMO-LER-NATURAL.md`](../COMO-LER-NATURAL.md) |
| **Estágio** | Estágio 1 — Arqueologia |
| **Resultado esperado** | Regras catalogadas com evidência `arquivo.NSN#L<início>-L<fim>` e mapa de dependências iniciado |

> [!NOTE]
> Estes arquivos são material de referência somente leitura. Durante o Estágio 1, os pares analisam os programas para extrair regras de negócio e mapeá-las para o sistema moderno (Java 21 + Spring Boot).

---

## O que existe nesta pasta

| Grupo | Quantos | Extensões | O que fazer com eles |
|---|---|---|---|
| **Programas** | 15 | `.NSN` | **Leitura atribuída.** 3 por par |
| **Membros de apoio** | 9 | `.NSA`, `.NSL`, `.NSC`, `.NSN`, `.jcl` | **Consulta sob demanda.** Infraestrutura compartilhada |

> [!IMPORTANT]
> **Sua carga de leitura não mudou: continuam sendo 3 programas por par.**
> Os 9 membros de apoio são a infraestrutura da biblioteca — áreas de dados, copycodes, dois subprogramas de validação e dois JCLs. Você abre um deles quando um dos *seus* programas faz `USING`, `INCLUDE` ou `CALLNAT` e você precisa saber o que aquele nome significa. Eles **não** são programas extras, **não** pertencem a nenhum par e **não** entram na conta das 3 leituras.

Tudo fica num diretório só porque uma biblioteca Natural é **plana**: `CALLNAT`, `INCLUDE` e `USING` resolvem os membros **pelo nome**, nunca por caminho. Ver [`COMO-LER-NATURAL.md`, seção 2](../COMO-LER-NATURAL.md#2-os-membros-de-uma-biblioteca-natural).

---

## 1. Os 15 programas — distribuição por par

| Par | Programa | Autor | Ano | Descrição |
|---|---|---|---|---|
| **1 · Visão** (PO + RE) — cadastro | `CADBENEF.NSN` | Roberto Meirelles | 1997 | Cadastro de beneficiário — inclusão, alteração, exclusão |
| | `CADDEPEND.NSN` | José A. Lima | 1998 | Cadastro de dependente vinculado ao beneficiário titular |
| | `CADPROG.NSN` | Fernanda C. Oliveira | 1997 | Cadastro de programa social — parâmetros e faixas de valores |
| **2 · Arquitetura** (EA + SA) — batch | `BATCHPGT.NSN` | José A. Lima | 1999 | Pagamento batch — gera os ciclos mensais de pagamento |
| | `BATCHREL.NSN` | José A. Lima | 1999 | Relatório batch — produz os relatórios gerenciais |
| | `BATCHCON.NSN` | Patrícia H. Moura | 2002 | Conciliação batch — reconcilia pagamentos com o SIAFI |
| **3 · Implementação** (TL + Dev) — cálculo | `CALCBENF.NSN` | Roberto Meirelles | 1998 | Cálculo do valor do benefício por programa e faixa |
| | `CALCCORR.NSN` | Marcos A. Ferreira | 2005 | Cálculo de correções e reajustes por índices anuais |
| | `CALCDSCT.NSN` | Marcos A. Ferreira | 2015 | Cálculo de descontos e deduções legais (consignações, IR) |
| **4 · Qualidade** (DBA + QA) — validação | `VALBENEF.NSN` | Roberto Meirelles | 1997 | Validação de dados cadastrais (CPF, NIS) |
| | `VALDOCS.NSN` | Patrícia H. Moura | 2003 | Validação de documentação comprobatória |
| | `VALELEG.NSN` | Fernanda C. Oliveira | 1999 | Validação de elegibilidade — cruzamento com regras do programa |
| **5 · Operações** (DevOps + TW) — consulta e relatório | `CONSBENF.NSN` | Roberto Meirelles | 1997 | Consulta de beneficiário por múltiplos critérios (tela 3270) |
| | `RELPGT.NSN` | Patrícia H. Moura | 2003 | Relatório de pagamentos por período, programa e UF |
| | `RELAUDIT.NSN` | Marcos A. Ferreira | 2005 | Relatório de auditoria — ocorrências e divergências |

---

## 2. Os 9 membros de apoio — infraestrutura compartilhada

Nenhum destes membros pertence a um par, e nenhum deles conta como leitura atribuída.

| Membro | Tipo | Como aparece no código | Para que serve |
|---|---|---|---|
| `PDAVALID.NSA` | PDA | `PARAMETER USING PDAVALID` / `LOCAL USING PDAVALID` | Contrato de parâmetros da família de validação de documentos: CPF e NIS entram, código de retorno e mensagem saem |
| `PDACALC.NSA` | PDA | `PARAMETER USING PDACALC` / `LOCAL USING PDACALC` | Contrato de parâmetros da cadeia de pagamento: chave e contexto do beneficiário entram, valores calculados saem |
| `LDASIFAP.NSL` | LDA | `LOCAL USING LDASIFAP` | Tabelas paramétricas compartilhadas: fator regional, faixas de renda, alíquotas, UF, datas e a janela de século (Y2K) |
| `CCVALCPF.NSC` | Copycode | `INCLUDE CCVALCPF` + `PERFORM VALIDA-CPF-PADRAO` | Rotina de mod-11 de CPF colada em tempo de compilação — o caminho **antigo** de validação |
| `CCAUDIT.NSC` | Copycode | `INCLUDE CCAUDIT` + `PERFORM GRAVA-AUDITORIA` | Bloco padrão de gravação da trilha de auditoria no ARQ 153 |
| `SUBVALCP.NSN` | Subprograma | `CALLNAT 'SUBVALCP' ...` | Validação de CPF (mod-11) chamável — o caminho **novo** de validação |
| `SUBVALNI.NSN` | Subprograma | `CALLNAT 'SUBVALNI' ...` | Validação de NIS/PIS/PASEP (mod-11) chamável |
| `SIFAPJ01.jcl` | JCL z/OS | fora do Natural | Job da **folha mensal de pagamento** — executa `BATCHPGT` via `NATBATCH` |
| `SIFAPJ02.jcl` | JCL z/OS | fora do Natural | Job **mensal de relatórios** — executa `BATCHREL` e `RELPGT` |

> [!NOTE]
> `SUBVALCP.NSN` e `SUBVALNI.NSN` têm extensão `.NSN` como os programas, mas são **subprogramas**: só existem para serem chamados por `CALLNAT` e não fazem `INPUT` nem `WRITE`. Eles não estão entre os 15.

---

## 3. Do JCL ao programa — o batch em produção

Os dois JCLs tornam o fluxo mensal rastreável de ponta a ponta:

| Job | Quando roda | O que executa | Produz |
|---|---|---|---|
| `SIFAPJ01.jcl` | Mensal — 1º dia útil | `BATCHPGT` | Folha de pagamento do mês e o arquivo de remessa bancária |
| `SIFAPJ02.jcl` | Mensal — 2º dia útil, depois do `SIFAPJ01` | `BATCHREL` e `RELPGT` | Relatório consolidado e relatório analítico por programa |

Cada JCL traz, em comentário, o agendamento (Control-M), os arquivos alocados e o procedimento de restart. É a melhor fonte para responder "o que acontece todo mês, e em que ordem".

---

## 4. Mapa de dependências — como construir

Os membros desta pasta se referenciam entre si. Descobrir **quem chama quem** é o exercício de mapa de dependências do Estágio 1: o resultado vai para [`dependency-map.md`](../../dependency-map.md), não está publicado aqui.

**Os quatro tipos de aresta e como encontrá-los:**

```bash
cd 01-arqueologia/legado-sifap/natural-programs

grep -n "CALLNAT" *.NSN          # chamada de subprograma  (aresta entre módulos)
grep -n "INCLUDE" *.NSN          # copycode colado         (aresta para .NSC)
grep -n "USING"   *.NSN          # PDA e LDA utilizadas    (aresta para .NSA/.NSL)
grep -n -A 8 "CMSYNIN" *.jcl     # que programa cada job executa
```

No VS Code, o equivalente é Ctrl+Shift+F com a expressão regular `CALLNAT|INCLUDE|USING` e o filtro de arquivos `*.NSN`.

**O que registrar para cada aresta encontrada:**

| Campo | Exemplo |
|---|---|
| Origem | `BATCHPGT` |
| Tipo | `CALLNAT` · `INCLUDE` · `USING` · `JCL executa` |
| Destino | nome do membro chamado |
| Evidência | `arquivo.NSN#L<linha>` |

> [!TIP]
> Três orientações que economizam tempo:
>
> 1. **Confirme cada aresta no código.** O comentário de cabeçalho é indício, não prova: ele pode citar uma dependência que o corpo do programa não tem, ou omitir uma que tem.
> 2. **Algumas arestas cruzam pares.** Se um programa seu chama um programa de outro par, combine a leitura com esse par antes de fechar o mapa — é assim que o desenho do sistema aparece.
> 3. **Comece pelos membros de apoio.** Buscar pelos nomes `SUBVALCP`, `SUBVALNI`, `CCVALCPF`, `CCAUDIT`, `PDAVALID`, `PDACALC` e `LDASIFAP` no diretório inteiro dá o esqueleto do grafo em poucos minutos.

---

### Continuar a leitura

| Anterior | Próximo |
|---|---|
| [Legado SIFAP — visão geral](../README.md)<br/><sub>Contexto do sistema e histórico.</sub> | [Adabas DDMs](../adabas-ddms/README.md)<br/><sub>Estruturas de dados Adabas.</sub> |

<sub>[Voltar ao índice do kit](../../../README.md)</sub>
