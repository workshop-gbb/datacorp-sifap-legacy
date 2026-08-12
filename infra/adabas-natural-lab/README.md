<!-- markdownlint-disable MD013 MD033 MD041 -->

# Lab Adabas + Natural — runtime legado opcional

> **Trilha:** [Kit do Time](../../README.md) › [Estágio 1 — Arqueologia](../../01-arqueologia/README.md) › **Lab Adabas + Natural**

**Provisiona uma VM no Azure com Adabas Community Edition e Natural Community Edition em containers, para quem quer executar os programas legados do SIFAP em vez de apenas lê-los.**

![Tipo Runbook](https://img.shields.io/badge/Tipo-Runbook-171717?style=flat-square) ![Trilha opcional](https://img.shields.io/badge/Trilha-Opcional-737373?style=flat-square) ![Custo Assinatura Azure](https://img.shields.io/badge/Custo-Assinatura%20Azure-A3A3A3?style=flat-square)

| Campo | Valor |
|---|---|
| **Público-alvo** | DevOps Engineer (Par 5) e quem quiser executar o legado de verdade |
| **Pré-requisitos** | Assinatura Azure própria, Azure CLI autenticado, Terraform 1.5+, par de chaves SSH |
| **Tempo estimado** | 15 min de comandos, mais o tempo do primeiro boot da VM |
| **Estágio** | Trilha opcional — apoio ao Estágio 1 (Arqueologia) |
| **Resultado esperado** | Adabas CE e Natural CE em execução em uma VM alcançável apenas pelo seu IP |

> [!CAUTION]
> Este módulo cria recursos pagos em uma assinatura Azure real. Leia [Custo e controle de gasto](#custo-e-controle-de-gasto) antes do primeiro `terraform apply`.

---

## O que este módulo entrega

O Terraform deste diretório cria um ambiente isolado com um runtime legado funcional:

- Uma VM Linux (Ubuntu 22.04 LTS) com Docker instalado no primeiro boot;
- O container `adabas-db` com Adabas Community Edition e um banco de demonstração;
- O container `natural-ce` com Natural Community Edition, já mapeado para o Adabas;
- Um Key Vault que guarda a senha de administração do Adabas, gerada no `apply`;
- Um Network Security Group que libera as portas do lab somente para os IPs que você declarar;
- Um agendamento de desligamento diário da VM, para conter custo.

O objetivo é permitir que você carregue os fontes Natural do SIFAP, compile (CATALL/STOW) e execute os programas em um runtime real. O módulo entrega o runtime pronto e o ponto de montagem dos fontes; a carga e a compilação dos programas acontecem dentro do container e não são automatizadas aqui.

### Quando você não precisa deste lab

O caminho principal do workshop não depende deste ambiente. Nos Estágios 1 a 4, o legado SIFAP é material de leitura: os programas Natural e os DDMs em [`01-arqueologia/legado-sifap/`](../../01-arqueologia/legado-sifap/) são arquivos de texto, e a rastreabilidade exigida no Estágio 2 (`source_legacy:`) aponta para esses arquivos, não para uma execução.

| Situação | Você precisa do lab? |
|---|---|
| Ler os programas, catalogar regras e escrever requisitos EARS | Não |
| Implementar o SIFAP 2.0 em Java 21 + Next.js 15 | Não |
| Passar nos portões de CI do workshop | Não |
| Ver a sintaxe Natural sendo compilada e executada de fato | Sim |
| Confirmar o comportamento de um programa cujo código ficou ambíguo na leitura | Sim |
| Demonstrar a diferença entre o runtime legado e a arquitetura moderna | Sim |

> [!NOTE]
> Trate este lab como trilha avançada e opcional. Nenhum artefato obrigatório do workshop depende dele.

---

## Arquitetura provisionada

```mermaid
%%{init: {'theme':'neutral','themeVariables':{'fontFamily':'ui-sans-serif, system-ui, sans-serif','primaryColor':'#F5F5F5','primaryTextColor':'#171717','primaryBorderColor':'#171717','lineColor':'#525252','secondaryColor':'#FFFFFF','tertiaryColor':'#FAFAFA','background':'#FFFFFF'}}}%%
flowchart LR
    classDef step fill:#F5F5F5,stroke:#171717,color:#171717
    classDef alt fill:#FFFFFF,stroke:#525252,color:#171717
    classDef muted fill:#FAFAFA,stroke:#A3A3A3,color:#404040
    classDef result fill:#FFFFFF,stroke:#171717,color:#171717,stroke-width:2px

    DEV["Seu laptop<br/>IP declarado em allowed_source_cidrs"]:::step
    NSG["NSG sifap-lab-nsg-brs<br/>22 · 2700 · 60001 · 8190"]:::alt
    VM["VM sifap-lab-vm-brs<br/>Ubuntu 22.04 · Docker"]:::step
    NAT["Container natural-ce<br/>Natural CE · porta 2700"]:::result
    ADA["Container adabas-db<br/>Adabas CE · DBID 12"]:::result
    KV["Key Vault do lab<br/>segredo adabas-admin-password"]:::muted

    DEV --> NSG --> VM
    VM --> NAT
    VM --> ADA
    NAT -->|"adatcp://adabas-db:60001"| ADA
    VM -.->|"managed identity"| KV
```

Nomes seguem a convenção `{project}-{env}-{resource}-{region}` de [`infrastructure.instructions.md`](../../.github/instructions/infrastructure.instructions.md). Com os valores padrão (`project = sifap`, `environment = lab`, `location_short = brs`), o grupo de recursos é `sifap-lab-rg-brs`.

---

## Pré-requisitos

- [ ] **Ter uma assinatura Azure com permissão de criação.** Você precisa criar grupo de recursos, VM, Key Vault e políticas de acesso. Confirme com `az account show`.
- [ ] **Instalar e autenticar o Azure CLI.** Rode `az login` e, se tiver mais de uma assinatura, `az account set --subscription "<ID-DA-ASSINATURA>"`.
- [ ] **Instalar o Terraform 1.5.0 ou superior.** O requisito está em `versions.tf` (`required_version = ">= 1.5.0"`). Verifique com `terraform version`.
- [ ] **Ter um par de chaves SSH.** O módulo lê a chave pública indicada em `ssh_public_key_path`, cujo padrão é `~/.ssh/id_rsa.pub`. Se não existir, gere com `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa`.
- [ ] **Confirmar cota de vCPU na região.** O padrão é `Standard_D2s_v3` (2 vCPU / 8 GB) em `brazilsouth`. Uma assinatura nova costuma ter cota baixa ou zerada.
- [ ] **Aceitar o custo.** A VM, os discos Premium SSD e o IP público estático são cobrados enquanto existirem.

Comandos para conferir região, tamanho e cota antes de aplicar:

```bash
az account show --output table
az vm list-skus --location brazilsouth --size Standard_D2s_v3 --all --output table
az vm list-usage --location brazilsouth --output table
```

> [!IMPORTANT]
> O estado do Terraform é local: `.gitignore` ignora `*.tfstate`. Quem roda o `apply` fica responsável pelo `destroy`, porque só aquele laptop tem o estado.

---

## Deploy passo a passo

- [ ] **Passo 1 — Entrar no diretório do módulo.**

```bash
cd infra/adabas-natural-lab
```

- [ ] **Passo 2 — Criar seu arquivo de variáveis.**

```bash
cp terraform.tfvars.example terraform.tfvars
```

- [ ] **Passo 3 — Descobrir seu IP público.**

```bash
curl -s https://api.ipify.org
```

- [ ] **Passo 4 — Preencher `terraform.tfvars`.** Duas variáveis são obrigatórias: `owner` e `allowed_source_cidrs`. Use o IP do passo anterior com máscara `/32`.

```hcl
owner = "seu-handle-github"

allowed_source_cidrs = [
  "<SEU-IP-PUBLICO>/32",
]
```

- [ ] **Passo 5 — Inicializar os providers.**

```bash
terraform init
```

- [ ] **Passo 6 — Gerar e revisar o plano.**

```bash
terraform plan -out=lab.tfplan
```

- [ ] **Passo 7 — Aplicar.**

```bash
terraform apply lab.tfplan
```

- [ ] **Passo 8 — Ler as saídas.**

```bash
terraform output
```

> [!WARNING]
> `terraform.tfvars` está no `.gitignore` do módulo porque contém endereços IP reais de participantes. Somente `terraform.tfvars.example` é versionado. O mesmo vale para `*.tfplan`, que pode carregar valores sensíveis em texto claro. Nunca force o commit desses arquivos.

Uma validação do módulo rejeita `0.0.0.0/0` em `allowed_source_cidrs`. O motivo está documentado em `variables.tf`: o Adabas CE não oferece criptografia de canal e o Natural Development Server não tem autenticação forte, então um listener aberto é caminho direto de comprometimento.

---

## Como conectar

O `apply` termina, mas a VM ainda executa o bootstrap: instalação do Docker, formatação do disco de dados, leitura do segredo no Key Vault e download das imagens. Acompanhe o log antes de tentar usar os endpoints (veja [Bootstrap ainda rodando](#bootstrap-ainda-rodando)).

| O que você quer | Output do Terraform | Como usar |
|---|---|---|
| Sessão SSH na VM | `ssh_command` | Comando pronto, no formato `ssh sifapadmin@<IP-PUBLICO>` |
| IP público da VM | `public_ip` | Use em ferramentas que pedem só o endereço |
| Endpoint do Natural Development Server | `natural_development_server` | Registre como servidor remoto no NaturalONE, no formato `<IP-PUBLICO>:2700` |
| Administração REST do Adabas | `adabas_admin_url` | Abra no navegador, no formato `http://<IP-PUBLICO>:8190` |
| Senha de administração do Adabas | `adabas_admin_password_command` | Imprime o comando `az keyvault secret show` já com o nome do cofre |
| Log do bootstrap | `bootstrap_log_command` | Imprime o comando de `tail -f` no log da VM |
| Nome do grupo de recursos | `resource_group_name` | Use nos comandos `az` e para conferir a remoção |
| Nome da VM | `vm_name` | Use em `az vm deallocate` e `az vm start` |

Para obter um valor sem aspas, use `-raw`:

```bash
terraform output -raw ssh_command
terraform output -raw natural_development_server
terraform output -raw adabas_admin_url
```

A administração REST do Adabas usa o usuário `admin`, definido em `cloud-init.yaml`. A conexão é HTTP, sem TLS: é justamente por isso que o NSG restringe a porta ao seu CIDR.

### Ler a senha do Adabas no Key Vault

A senha é gerada pelo Terraform, gravada no Key Vault e lida pela VM através da identidade gerenciada. Ela nunca aparece em variáveis de entrada nem neste repositório.

```bash
# 1. Imprime o comando pronto, já com o nome real do cofre
terraform output -raw adabas_admin_password_command

# 2. Execute o comando impresso acima para ver a senha no terminal
```

O comando impresso tem esta forma:

```bash
az keyvault secret show --vault-name <NOME-DO-COFRE> --name adabas-admin-password --query value -o tsv
```

> [!WARNING]
> Não copie a senha para arquivos do repositório, issues, PRs ou mensagens. Leia do Key Vault sempre que precisar.

### Levar os fontes do SIFAP para o container

O bootstrap cria o diretório `/opt/sifap/corpus` na VM e o monta como somente leitura em `/corpus` dentro do container `natural-ce`. O módulo prepara o ponto de montagem, mas não copia nada: a carga dos fontes é sua.

```bash
# Do diretório raiz do repositório, no seu laptop
scp -r 01-arqueologia/legado-sifap/natural-programs sifapadmin@<IP-PUBLICO>:/tmp/

# Na VM, mover para o diretório montado no container
ssh sifapadmin@<IP-PUBLICO> 'sudo cp /tmp/natural-programs/* /opt/sifap/corpus/'
```

Depois, abra um shell no container para trabalhar com os fontes:

```bash
sudo docker exec -it natural-ce bash
ls /corpus
```

---

## Portas liberadas e função de cada uma

As regras estão em `main.tf`, no recurso `azurerm_network_security_group.lab`. Todas usam TCP e têm como origem apenas os CIDRs de `allowed_source_cidrs`. A regra `DenyAllOtherInbound`, com prioridade 4096, bloqueia todo o resto.

| Porta | Regra no NSG | Prioridade | Para que serve |
|---|---|---|---|
| 22 | `AllowSshFromWorkshop` | 100 | SSH na VM. Autenticação por chave; senha está desabilitada |
| 2700 | `AllowNaturalDevelopmentServer` | 110 | Natural Development Server. É a porta que o NaturalONE usa para se conectar ao ambiente remoto |
| 60001 | `AllowAdabasAdatcp` | 120 | ADATCP do Adabas. Só é necessária quando um cliente Adabas roda fora da VM; a comunicação entre os containers usa a rede interna do Docker |
| 8190 | `AllowAdabasRestAdmin` | 130 | Interface REST de administração do Adabas |

---

## Variáveis do módulo

Somente duas variáveis são obrigatórias. As demais têm padrão definido em `variables.tf`.

| Variável | Obrigatória | Padrão | Para que serve |
|---|---|---|---|
| `owner` | Sim | — | Tag de responsável: handle do GitHub ou e-mail |
| `allowed_source_cidrs` | Sim | — | CIDRs liberados nas quatro portas. `0.0.0.0/0` é rejeitado por validação |
| `project` | Não | `sifap` | Prefixo de nome e tag. De 2 a 12 caracteres minúsculos alfanuméricos |
| `environment` | Não | `lab` | Aceita `lab`, `dev` ou `workshop` |
| `cost_center` | Não | `workshop-legacy-modernization` | Tag de rateio de custo |
| `location` | Não | `brazilsouth` | Região Azure |
| `location_short` | Não | `brs` | Código curto usado no nome dos recursos |
| `vm_size` | Não | `Standard_D2s_v3` | 2 vCPU / 8 GB, piso prático para Adabas CE e Natural CE juntos |
| `admin_username` | Não | `sifapadmin` | Usuário administrador da VM. O `cloud-init.yaml` adiciona `sifapadmin` ao grupo `docker` de forma fixa, então trocar este valor obriga a usar `sudo` para os comandos Docker |
| `ssh_public_key_path` | Não | `~/.ssh/id_rsa.pub` | Caminho da chave pública autorizada |
| `data_disk_size_gb` | Não | `32` | Tamanho do disco gerenciado que guarda os containers de banco |
| `adabas_image` | Não | `softwareag/adabas-ce:7.4.0` | Imagem do Adabas Community Edition |
| `natural_image` | Não | `softwareag/natural-ce:9.3.3` | Imagem do Natural Community Edition |
| `adabas_dbid` | Não | `12` | DBID do Adabas que o Natural mapeia |
| `auto_shutdown_time` | Não | `2000` | Horário do desligamento diário, no formato HHmm |
| `auto_shutdown_timezone` | Não | `E. South America Standard Time` | Fuso do agendamento de desligamento |
| `auto_shutdown_notification_email` | Não | `""` | E-mail avisado 30 minutos antes. Vazio desativa o aviso |

---

## Custo e controle de gasto

O output `estimated_cost_note` traz a estimativa do próprio módulo: cerca de **USD 0,20 por hora** com a VM ligada e cerca de **USD 0,04 por hora** (≈ USD 1/dia) com a VM desligada, considerando `Standard_D2s_v3`, discos Premium SSD e IP estático. Os valores vêm de preços de varejo (pay-as-you-go) da região `brazilsouth` consultados na Azure Retail Prices API. Confirme os valores da sua região e do seu contrato antes de assumir esse número.

Três mecanismos protegem a fatura, do mais fraco ao mais forte:

| Mecanismo | O que faz | Quando usar |
|---|---|---|
| Desligamento automático | Desliga a VM todo dia às 20h00, no fuso `E. South America Standard Time` | Sempre ativo; funciona como rede de segurança, não como plano de uso |
| `az vm deallocate` | Para a cobrança de computação e mantém o ambiente | Pausa entre sessões, quando você vai voltar ao lab |
| `terraform destroy` | Remove todos os recursos | Terminou de usar o lab |

Para pausar e retomar:

```bash
az vm deallocate \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name "$(terraform output -raw vm_name)"

az vm start \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name "$(terraform output -raw vm_name)"
```

> [!IMPORTANT]
> `az vm deallocate` para a cobrança de computação, mas os discos gerenciados (64 GB de SO e 32 GB de dados, ambos Premium SSD) e o IP público estático continuam sendo cobrados. Para zerar o custo, use `terraform destroy`.

O IP público é estático, então ele não muda quando você desliga e liga a VM.

---

## Solução de problemas

| Sintoma | Causa provável | Correção |
|---|---|---|
| `terraform plan` falha ao ler a chave SSH | O arquivo em `ssh_public_key_path` não existe | Gere o par de chaves ou ajuste a variável para o caminho correto |
| SSH dá timeout | Seu IP público mudou e não está mais em `allowed_source_cidrs` | Atualize `terraform.tfvars` e rode `terraform apply` de novo |
| `Permission denied (publickey)` | A chave privada usada não corresponde à pública enviada | Conecte com `ssh -i ~/.ssh/id_rsa sifapadmin@<IP-PUBLICO>` |
| Portas 2700, 8190 ou 60001 sem resposta | Bootstrap ainda em andamento ou container parado | Acompanhe o log do bootstrap e verifique os containers |
| A senha do Key Vault é rejeitada pelo Adabas | O bootstrap não conseguiu ler o segredo e gerou uma senha local | Procure `could not read the Key Vault secret` no log; se confirmado, recrie a VM com `terraform apply -replace=azurerm_linux_virtual_machine.lab` |
| `docker` responde `permission denied` | A adesão ao grupo `docker` só vale em nova sessão | Reconecte o SSH ou use `sudo docker ...` |
| `apply` falha com erro de SKU ou de cota | Região sem `Standard_D2s_v3` ou sem cota de vCPU | Troque a região ou o tamanho da VM |

### Bootstrap ainda rodando

O primeiro boot instala o Docker e baixa vários GB de imagens. Esse download é a etapa lenta, e a duração depende da banda da região. Acompanhe em vez de estimar:

```bash
terraform output -raw bootstrap_log_command
```

O comando impresso tem esta forma:

```bash
ssh sifapadmin@<IP-PUBLICO> 'sudo tail -f /var/log/sifap-bootstrap.log'
```

O log começa com `=== SIFAP lab bootstrap started` e termina com `=== SIFAP lab bootstrap finished`. Ao final, o bootstrap cria o arquivo marcador `/opt/sifap/READY`. Para uma verificação rápida:

```bash
ssh sifapadmin@<IP-PUBLICO> 'ls -l /opt/sifap/READY'
```

### SSH recusado ou sem resposta

Esta é a falha mais comum do lab, e quase sempre tem a mesma causa: **seu IP público mudou**. Redes domésticas, VPNs corporativas e conexões móveis trocam de endereço com frequência. O NSG continua liberando o IP antigo e a regra `DenyAllOtherInbound` bloqueia o novo.

```bash
# 1. Verifique seu IP atual
curl -s https://api.ipify.org

# 2. Compare com o que está declarado
grep -A3 allowed_source_cidrs terraform.tfvars

# 3. Se forem diferentes, atualize o arquivo e reaplique
terraform apply
```

O `apply` altera apenas as regras do NSG. A VM e os containers continuam de pé.

### Containers não sobem

Conecte na VM e inspecione o Compose gerado pelo bootstrap, que fica em `/opt/sifap/docker-compose.yml`:

```bash
cd /opt/sifap
sudo docker compose ps
sudo docker compose logs adabas-db
sudo docker compose logs natural-ce
sudo docker compose up -d
```

Os dois containers compartilham a rede bridge `sifap-lab`, e o `natural-ce` alcança o banco pelo nome `adabas-db`. Se o `adabas-db` não subir, o `natural-ce` também não fica utilizável.

### Região sem cota ou sem o tamanho de VM

Nem toda região oferece `Standard_D2s_v3`, e assinaturas novas costumam ter cota baixa. Confirme com os comandos de pré-requisito e, se precisar mudar de região, ajuste `location` e `location_short` juntos para manter o padrão de nomes:

```hcl
location       = "eastus2"
location_short = "eus2"
```

Se preferir manter a região e trocar o tamanho, lembre do piso documentado em `variables.tf`: Adabas CE e Natural CE consomem juntos algo entre 4 GB e 6 GB de RAM.

---

## Destruir o ambiente

- [ ] **Passo 1 — Guardar o nome do grupo de recursos.** Depois do `destroy`, os outputs deixam de existir.

```bash
cd infra/adabas-natural-lab
terraform output -raw resource_group_name
```

- [ ] **Passo 2 — Destruir tudo.** Confirme digitando `yes` quando o Terraform pedir.

```bash
terraform destroy
```

- [ ] **Passo 3 — Confirmar que nada sobrou.** O comando deve falhar informando que o grupo não existe.

```bash
az group show --name "<NOME-DO-GRUPO-DE-RECURSOS>"
```

> [!CAUTION]
> `terraform destroy` remove a VM, os discos e todos os dados carregados no Adabas. Se você tem trabalho dentro do lab que quer preservar, copie para fora antes.

### Key Vault e a janela de soft-delete

O Key Vault do lab usa `soft_delete_retention_days = 7` e `purge_protection_enabled = false`. O provider está configurado em `versions.tf` com `purge_soft_delete_on_destroy = true` e `recover_soft_deleted_key_vaults = true`, ou seja, o `destroy` normalmente já expurga o cofre e um novo `apply` recupera um cofre excluído com o mesmo nome.

O problema aparece quando o `destroy` é interrompido ou a conta não tem permissão de purge. Nesse caso o nome fica reservado por até 7 dias e um novo `apply` com o mesmo nome falha. O nome inclui um sufixo aleatório de 6 caracteres, então a colisão ocorre quando você reaplica com o mesmo estado do Terraform.

```bash
# Ver cofres em soft-delete
az keyvault list-deleted --output table

# Remover em definitivo o cofre do lab
az keyvault purge --name "<NOME-DO-COFRE>" --location brazilsouth
```

---

## Critérios de conclusão

- [ ] `terraform output` retorna os endpoints do lab.
- [ ] O log do bootstrap terminou e `/opt/sifap/READY` existe.
- [ ] `sudo docker compose ps` mostra `adabas-db` e `natural-ce` em execução.
- [ ] A administração REST do Adabas abre com o usuário `admin` e a senha lida do Key Vault.
- [ ] `terraform.tfvars` continua fora do controle de versão.
- [ ] Ao terminar, você rodou `az vm deallocate` (pausa) ou `terraform destroy` (remoção).

---

## Referências

| Recurso | Onde |
|---|---|
| Convenções de infraestrutura do kit | [`.github/instructions/infrastructure.instructions.md`](../../.github/instructions/infrastructure.instructions.md) |
| Programas Natural e DDMs do SIFAP | [`01-arqueologia/legado-sifap/`](../../01-arqueologia/legado-sifap/) |
| Como ler código Natural | [`01-arqueologia/legado-sifap/COMO-LER-NATURAL.md`](../../01-arqueologia/legado-sifap/COMO-LER-NATURAL.md) |
| Runbook operacional do workshop | [`docs/runbook.md`](../../docs/runbook.md) |
| Solução de problemas do workshop | [`docs/troubleshooting.md`](../../docs/troubleshooting.md) |

---

### Continuar a leitura

| Anterior | Próximo |
|---|---|
| [Estágio 1 — Arqueologia](../../01-arqueologia/README.md)<br/><sub>Visão geral do estágio que este lab apoia.</sub> | [Legado SIFAP](../../01-arqueologia/legado-sifap/README.md)<br/><sub>Documentação do sistema legado e inventário de programas.</sub> |

<sub>[Voltar ao índice do kit](../../README.md)</sub>
