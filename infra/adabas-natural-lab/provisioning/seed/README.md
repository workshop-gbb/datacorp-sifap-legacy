# Dados sintéticos de seed do lab legado SIFAP

Este diretório contém arquivos de seed determinísticos e de largura fixa para o lab Adabas/Natural do SIFAP.

**Declaração sobre dados sintéticos:** estes são dados brasileiros de teste 100% sintéticos. Eles não contêm dados pessoais reais, atribuições reais de CPF/NIS nem registros de produção.

## Arquivos e volumes

| Arquivo | Registros | Bytes/registro (sem quebra de linha) | Layout de origem |
|---|---:|---:|---|
| `beneficiary.dat` | 500 | 1739 | `layout-beneficiary.txt`, file 150 BENEFICIARY |
| `payment.dat` | 2000 | 855 | `layout-payment.txt`, file 152 PAYMENT |
| `social-program.dat` | 6 | 361 | `layout-social-program.txt`, file 151 SOCIAL-PROGRAM |
| `audit.dat` | 200 | 4995 | `layout-audit.txt`, file 153 AUDIT |

## Regeneração

Execute neste diretório ou na raiz do repositório:

```bash
python3 infra/adabas-natural-lab/provisioning/seed/generate_seed.py
```

O gerador usa somente a biblioteca padrão do Python 3 e uma seed fixa do gerador de números aleatórios, portanto as saídas são reproduzíveis.

## Observações sobre o layout

Cada linha contém um registro físico. Os campos alfanuméricos usam ASCII e recebem espaços à direita. Os campos numéricos não compactados recebem zeros à esquerda. Os campos decimais compactados usam BCD binário compactado, com a escala decimal implícita declarada no DDM/FDT; a quebra de linha não faz parte da largura do registro.

Os grupos periódicos e campos MU são emitidos com suas contagens máximas de ocorrências para que os scripts ADACMP/ADALOD relacionados carreguem registros determinísticos com largura total.

## Fixtures didáticas

- Os dígitos verificadores válidos de CPF e NIS são gerados com os algoritmos de módulo 11 usados por `SUBVALCP.NSN` e `SUBVALNI.NSN`.
- Vários beneficiários têm valores de CPF válidos iniciados por `000` para o caminho de exceção de teste governamental.
- As rendas familiares atravessam as faixas de cálculo 300/600/1000/1500.
- Os beneficiários da região `99` exercitam a exceção de elegibilidade internacional/diplomática.
- Os dependentes incluem nenhuma e várias ocorrências, status inativos/desvinculados e um registro com o máximo de 10 ocorrências.
- Os pagamentos incluem estornos, conciliação divergente, devoluções bancárias e linhas de bruto/desconto/líquido intencionalmente desequilibradas para os labs de relatórios.
