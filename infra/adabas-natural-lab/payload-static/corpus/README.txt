This directory is mounted read-only into the Natural container as /corpus.

NOTHING IS COPIED BY HAND. deploy-local.sh packages the frozen SIFAP
sources from 01-archaeology/legacy-sifap/ with a SHA-256 manifest,
uploads the archive over the allow-listed SSH path, and invokes
/opt/sifap/fetch-payload.sh to install it:

  natural-programs/   22 Natural members + 2 JCL jobs
  adabas-ddms/        4 DDMs + the FDT for file 150

If those directories are empty, payload delivery did not complete. It
says so in /var/log/sifap-bootstrap.log. Re-run from the repository:

  infra/adabas-natural-lab/deploy-local.sh upload
