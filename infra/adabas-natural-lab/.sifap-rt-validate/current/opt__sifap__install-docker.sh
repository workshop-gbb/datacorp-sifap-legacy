#!/usr/bin/env bash
# Docker from the official repository; the Ubuntu archive build lags behind.
# Split out of runcmd so every network call can retry: first-boot DNS and
# egress on a fresh Azure VM are routinely flaky for the first few seconds.
set -euo pipefail

if command -v docker >/dev/null 2>&1; then
  echo "docker already installed; skipping repository setup"
else
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL --retry 5 --retry-delay 3 --retry-connrefused \
    https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Derive the codename instead of hardcoding "jammy", so the file keeps
  # working if source_image_reference is ever moved to a newer Ubuntu LTS.
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list

  for attempt in $(seq 1 5); do
    apt-get update && break
    echo "apt-get update failed (attempt $attempt/5); retrying"
    sleep 10
  done

  for attempt in $(seq 1 5); do
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && break
    echo "docker install failed (attempt $attempt/5); retrying"
    sleep 10
  done
fi

systemctl enable docker

# Every human who can sudo on this box should be able to drive docker.
# Derived from the sudo group rather than hardcoding the admin username,
# which is a Terraform variable and not passed into this template.
for u in $(getent group sudo | cut -d: -f4 | tr ',' ' '); do
  [ -n "$u" ] && usermod -aG docker "$u" || true
done

echo "docker install step finished"
