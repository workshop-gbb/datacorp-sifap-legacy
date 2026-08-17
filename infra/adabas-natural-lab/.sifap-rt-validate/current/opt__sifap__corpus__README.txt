This directory is mounted read-only into the Natural container as /corpus.

NOTHING IS COPIED BY HAND ANY MORE. Terraform stages the frozen SIFAP
sources from 01-archaeology/legacy-sifap/ into a private blob container,
and /opt/sifap/fetch-payload.sh pulls them down at first boot using the
VM's managed identity, verifying every file against a SHA-256 manifest:

  natural-programs/   22 Natural members + 2 JCL jobs
  adabas-ddms/        4 DDMs + the FDT for file 150

If those directories are empty, the download failed. It says so in
/var/log/sifap-bootstrap.log, and the fix is to re-run:

  sudo /opt/sifap/fetch-payload.sh

The usual cause is a missing "Storage Blob Data Reader" assignment for the
VM identity - see var.assign_vm_blob_role in the module.
