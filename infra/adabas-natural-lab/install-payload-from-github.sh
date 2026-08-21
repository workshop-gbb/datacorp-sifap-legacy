#!/usr/bin/env bash
set -Eeuo pipefail

COMMIT="${1:-}"
REPOSITORY="${SIFAP_GITHUB_REPOSITORY:-paulasilvatech/datacorp-sifap-team-kit-pt-br}"
WORK_DIR="$(mktemp -d)"
SOURCE_DIR="$WORK_DIR/source"
STAGE_DIR="$WORK_DIR/stage"
PAYLOAD_DIR="/opt/sifap/payload"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

[[ "$COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
  echo "commit must be a full 40-character SHA" >&2
  exit 2
}

mkdir -p "$SOURCE_DIR" "$STAGE_DIR/corpus" "$STAGE_DIR/provisioning" "$STAGE_DIR/www"
curl -fsSL --retry 5 --retry-delay 3 --retry-connrefused \
  "https://codeload.github.com/${REPOSITORY}/tar.gz/${COMMIT}" \
  -o "$WORK_DIR/source.tar.gz"
tar -xzf "$WORK_DIR/source.tar.gz" -C "$SOURCE_DIR" --strip-components=1

CORPUS_ROOT="$SOURCE_DIR/01-archaeology/legacy-sifap"
LAB_ROOT="$SOURCE_DIR/infra/adabas-natural-lab"
[ -d "$CORPUS_ROOT/natural-programs" ] || { echo "Natural corpus missing from commit" >&2; exit 1; }
[ -d "$CORPUS_ROOT/adabas-ddms" ] || { echo "DDM corpus missing from commit" >&2; exit 1; }
[ -d "$LAB_ROOT/provisioning" ] || { echo "provisioning scripts missing from commit" >&2; exit 1; }

cp -a "$CORPUS_ROOT/natural-programs" "$STAGE_DIR/corpus/"
cp -a "$CORPUS_ROOT/adabas-ddms" "$STAGE_DIR/corpus/"
cp -a "$LAB_ROOT/payload-static/." "$STAGE_DIR/"
tar -C "$LAB_ROOT/provisioning" \
  --exclude='./work' --exclude='./ngd-work' --exclude='./ddm-work' --exclude='./__pycache__' \
  -cf - . | tar -C "$STAGE_DIR/provisioning" -xf -

python3 - "$STAGE_DIR" "$COMMIT" <<'PY'
import hashlib
import pathlib
import sys

stage = pathlib.Path(sys.argv[1])
entries = []
for path in sorted(stage.rglob("*")):
    if not path.is_file() or path.name == "manifest.sha256":
        continue
    relative = path.relative_to(stage).as_posix()
    if not relative.startswith(("corpus/", "provisioning/", "www/")):
        raise SystemExit(f"unexpected payload path: {relative}")
    entries.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {relative}\n")
(stage / "manifest.sha256").write_text("".join(entries), encoding="utf-8")
print(f"Payload manifest: {len(entries)} files from commit {sys.argv[2]}")
PY

rm -rf "${PAYLOAD_DIR}.new"
mv "$STAGE_DIR" "${PAYLOAD_DIR}.new"
rm -rf "$PAYLOAD_DIR"
mv "${PAYLOAD_DIR}.new" "$PAYLOAD_DIR"
printf '%s\n' "$COMMIT" > /opt/sifap/PAYLOAD-COMMIT

/opt/sifap/fetch-payload.sh
systemctl restart --no-block sifap-provisioning
echo "Payload installed from ${REPOSITORY}@${COMMIT}"