#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"
image="swift:6.4.1-jammy"

docker run --rm \
  --platform linux/amd64 \
  -e QEMU_CPU=max \
  -v "${project_root}:/workspace" \
  -w /workspace \
  "${image}" \
  bash -lc '
    swift build --disable-sandbox -c release --static-swift-stdlib --product cosmogai
    binary_dir="$(swift build --show-bin-path -c release --product cosmogai)"
    install -D -m 755 "${binary_dir}/cosmogai" Artifacts/cosmogai-linux-x86_64
    strip --strip-debug Artifacts/cosmogai-linux-x86_64
    readelf -h Artifacts/cosmogai-linux-x86_64 | grep -E "Class:|Machine:"
  '

echo "Built ${project_root}/Artifacts/cosmogai-linux-x86_64"
