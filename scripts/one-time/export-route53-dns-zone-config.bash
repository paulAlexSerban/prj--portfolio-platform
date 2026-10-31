#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="/usr/local/bin"

mkdir -p "${ROOT}/tmp"
touch "${ROOT}/tmp/route53-hosted-zones.json"
aws route53 list-hosted-zones --profile source > "${ROOT}/tmp/route53-hosted-zones.json"