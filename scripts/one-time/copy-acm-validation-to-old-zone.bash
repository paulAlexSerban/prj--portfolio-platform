#!/usr/bin/env bash
set -euo pipefail

# Copies ACM DNS-validation CNAMEs for paulserban.eu from the current AWS
# account into the hosted zone that is still authoritative, then waits until
# those certificates are issued.
#
# Load new-account credentials first (`set -a && source .env && set +a`).
# Point at the old account separately, then run from the repo root:
#
#   OLD_AWS_PROFILE=old-account bash scripts/one-time/copy-acm-validation-to-old-zone.bash
#
# or, instead of a profile:
#
#   OLD_AWS_ACCESS_KEY_ID=... OLD_AWS_SECRET_ACCESS_KEY=... \
#     bash scripts/one-time/copy-acm-validation-to-old-zone.bash
#
# OLD_HOSTED_ZONE_ID defaults to the zone exported from the source account.
# Create the certificates first with `make terraform-static-sites-certs`
# (or a full apply, which creates them too).

DOMAIN="${DOMAIN:-paulserban.eu}"
ACM_REGION="${ACM_REGION:-us-east-1}"
OLD_HOSTED_ZONE_ID="${OLD_HOSTED_ZONE_ID:-Z0098660U3Z7GN6KH4L1}"
WAIT_SECONDS="${WAIT_SECONDS:-1800}"

command -v aws >/dev/null
command -v jq >/dev/null

old_aws() {
    if [[ -n "${OLD_AWS_PROFILE:-}" ]]; then
        # Environment keys belong to the new account and would override --profile.
        env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \
            AWS_PROFILE="$OLD_AWS_PROFILE" \
            aws "$@"
    elif [[ -n "${OLD_AWS_ACCESS_KEY_ID:-}" && -n "${OLD_AWS_SECRET_ACCESS_KEY:-}" ]]; then
        env \
            AWS_ACCESS_KEY_ID="$OLD_AWS_ACCESS_KEY_ID" \
            AWS_SECRET_ACCESS_KEY="$OLD_AWS_SECRET_ACCESS_KEY" \
            AWS_SESSION_TOKEN="${OLD_AWS_SESSION_TOKEN:-}" \
            aws "$@"
    else
        echo "Set OLD_AWS_PROFILE, or OLD_AWS_ACCESS_KEY_ID and OLD_AWS_SECRET_ACCESS_KEY, for the account that still serves ${DOMAIN}." >&2
        exit 1
    fi
}

arns="$(
    aws acm list-certificates \
        --region "$ACM_REGION" \
        --certificate-statuses PENDING_VALIDATION ISSUED \
        --query 'CertificateSummaryList[].CertificateArn' \
        --output text
)"

if [[ -z "${arns}" || "${arns}" == "None" ]]; then
    echo "No ACM certificates in ${ACM_REGION}." >&2
    echo "Create them first: make terraform-static-sites-certs" >&2
    exit 1
fi

changes='[]'
pending_arns=()

for arn in $arns; do
    desc="$(aws acm describe-certificate --region "$ACM_REGION" --certificate-arn "$arn")"
    domain="$(jq -r '.Certificate.DomainName' <<<"$desc")"
    status="$(jq -r '.Certificate.Status' <<<"$desc")"

    case "$domain" in
        "$DOMAIN" | *."$DOMAIN") ;;
        *) continue ;;
    esac

    echo "certificate ${domain} is ${status}"
    if [[ "$status" == "PENDING_VALIDATION" ]]; then
        pending_arns+=("$arn")
    fi

    records="$(jq -c '
        .Certificate.DomainValidationOptions
        | map(
            select(.ResourceRecord != null)
            | {
                Action: "UPSERT",
                ResourceRecordSet: {
                    Name: .ResourceRecord.Name,
                    Type: .ResourceRecord.Type,
                    TTL: 60,
                    ResourceRecords: [{ Value: .ResourceRecord.Value }]
                }
            }
        )
    ' <<<"$desc")"
    changes="$(jq -c -n --argjson a "$changes" --argjson b "$records" '$a + $b')"
done

changes="$(jq -c 'unique_by(.ResourceRecordSet.Name)' <<<"$changes")"

if [[ "$changes" == "[]" ]]; then
    echo "No ACM certificates for ${DOMAIN} in ${ACM_REGION}." >&2
    echo "Create them first: make terraform-static-sites-certs" >&2
    exit 1
fi

echo "upserting $(jq 'length' <<<"$changes") validation records into zone ${OLD_HOSTED_ZONE_ID}"
old_aws route53 change-resource-record-sets \
    --hosted-zone-id "$OLD_HOSTED_ZONE_ID" \
    --change-batch "$(jq -n --argjson changes "$changes" '{Changes: $changes}')"

if [[ ${#pending_arns[@]} -eq 0 ]]; then
    echo "Every matching certificate is already issued."
    exit 0
fi

deadline=$((SECONDS + WAIT_SECONDS))
while true; do
    still_pending=0
    for arn in "${pending_arns[@]}"; do
        status="$(aws acm describe-certificate --region "$ACM_REGION" --certificate-arn "$arn" --query 'Certificate.Status' --output text)"
        echo "  ${status}  ${arn}"
        if [[ "$status" != "ISSUED" ]]; then
            still_pending=1
        fi
    done

    if [[ "$still_pending" -eq 0 ]]; then
        echo "All certificates are issued."
        exit 0
    fi

    if ((SECONDS >= deadline)); then
        echo "Timed out after ${WAIT_SECONDS}s waiting for ACM. Public DNS for the old zone may not have picked up the CNAMEs yet." >&2
        exit 1
    fi

    sleep 30
done
