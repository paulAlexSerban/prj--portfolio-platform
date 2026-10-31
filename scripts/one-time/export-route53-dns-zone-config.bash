#!/usr/bin/env bash
set -euo pipefail

# this script exports the DNS zone config for all hosted zones in the Route 53 account
# it is useful for debugging and troubleshooting DNS issues
# also useful for moving DNS zones between accounts

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="/usr/local/bin"

mkdir -p "${ROOT}/tmp"
touch "${ROOT}/tmp/route53-hosted-zones.json"
aws route53 list-hosted-zones > "${ROOT}/tmp/route53-hosted-zones.json"

for hosted_zone in $(jq -r '.HostedZones[].Id' "${ROOT}/tmp/route53-hosted-zones.json"); do
    zone_id="${hosted_zone##*/}"
    output="${ROOT}/tmp/route53-resource-record-sets-${zone_id}.json"
    aws route53 list-resource-record-sets \
        --hosted-zone-id "${zone_id}" \
        > "${output}"
done