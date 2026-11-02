#!/usr/bin/env bash
set -euo pipefail
# Set OHAM_SKILLS_SOURCE to the deployed repository's vendor/ohamlab/skills path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${OHAM_SKILLS_SOURCE:-${SCRIPT_DIR}/skills}"
TARGET="${OHAM_SKILLS_TARGET:-/data/dsh/skills}"
for skill in web-search agent-lab research-workflow; do
  test -f "${SOURCE}/${skill}/SKILL.md" || { echo "Missing skill ${skill}" >&2; exit 1; }
  mkdir -p "${TARGET}/${skill}"
  cp -a "${SOURCE}/${skill}/." "${TARGET}/${skill}/"
  echo "[OHAMLAB] Installed ${skill}"
done
