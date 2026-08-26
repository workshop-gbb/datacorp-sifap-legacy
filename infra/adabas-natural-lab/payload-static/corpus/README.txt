Este diretório é montado como somente leitura no contêiner Natural em /corpus.

NADA É COPIADO MANUALMENTE. deploy-local.sh empacota as fontes congeladas
do SIFAP em 01-archaeology/legacy-sifap/ com um manifesto SHA-256, envia o
arquivo pelo caminho SSH da lista de permissões e invoca
/opt/sifap/fetch-payload.sh para instalá-lo:

  natural-programs/   22 membros Natural + 2 jobs JCL
  adabas-ddms/        4 DDMs + a FDT do arquivo 150

Se esses diretórios estiverem vazios, a entrega do payload não foi
concluída. O erro aparece em /var/log/sifap-bootstrap.log. Execute novamente
a partir do repositório:

  infra/adabas-natural-lab/deploy-local.sh upload
