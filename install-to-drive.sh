#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${COSMOGAI_DRIVE_ROOT:-}" ]]; then
  echo "Set COSMOGAI_DRIVE_ROOT to the mounted MyDrive/CosmogAI folder." >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

cd "${project_root}"
swift build -c release --static-swift-stdlib --product cosmogai
binary_dir="$(swift build --show-bin-path -c release --product cosmogai)"
mkdir -p "${COSMOGAI_DRIVE_ROOT}"
install -m 755 "${binary_dir}/cosmogai" "${COSMOGAI_DRIVE_ROOT}/cosmogai"
echo "Installed ${COSMOGAI_DRIVE_ROOT}/cosmogai"
