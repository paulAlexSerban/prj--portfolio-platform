#!/usr/bin/env bash
set -euo pipefail

# Writes the static-sites Terraform outputs onto the portfolio repo's
# GitHub Environments. The environments must already exist.
#
#   production  -> site deploy role, buckets, distribution ids, account id
#   news-data   -> news-sync role, news JSON bucket, distribution id, account id
#
# Requires terraform (stack already applied), jq, and gh authenticated
# with permission to set Actions variables on the repo.
#
#   bash scripts/tools/sync-github-env-vars.bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK="${STACK:-${ROOT}/layers/05-workloads/terraform/static-sites}"
REPO="${GITHUB_REPO:-paulAlexSerban/prj--personal-portfolio--v3}"

for cmd in terraform jq gh; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing required command: ${cmd}" >&2
        exit 1
    fi
done

if ! gh auth status >/dev/null 2>&1; then
    echo "gh is not logged in. Run: gh auth login" >&2
    exit 1
fi

json="$(terraform -chdir="$STACK" output -json github_environment_variables)"

for env_name in production news-data; do
    if ! gh api "repos/${REPO}/environments/${env_name}" >/dev/null; then
        echo "GitHub Environment '${env_name}' does not exist on ${REPO}." >&2
        echo "Create it under Settings -> Environments, then re-run." >&2
        exit 1
    fi

    echo "setting variables on ${REPO} environment ${env_name}"
    while IFS=$'\t' read -r key value; do
        [[ -n "$key" ]] || continue
        gh variable set "$key" --repo "$REPO" --env "$env_name" --body "$value"
        echo "  ${key}"
    done < <(jq -r --arg env "$env_name" '.[$env] | to_entries[] | "\(.key)\t\(.value)"' <<<"$json")
done
