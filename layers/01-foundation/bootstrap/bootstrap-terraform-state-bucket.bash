#!/usr/bin/env bash
set -euo pipefail

# Creates the S3 bucket used as the Terraform state backend.
# Safe to re-run: an existing bucket is left in place and its settings are reapplied.

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
: "${AWS_REGION:?AWS_REGION is required}"

if aws s3api head-bucket --bucket "${TF_STATE_BUCKET}" >/dev/null 2>&1; then
    echo "bucket ${TF_STATE_BUCKET} already exists"
else
    if [[ "${AWS_REGION}" == "us-east-1" ]]; then
        aws s3api create-bucket --bucket "${TF_STATE_BUCKET}"
    else
        aws s3api create-bucket \
            --bucket "${TF_STATE_BUCKET}" \
            --create-bucket-configuration "LocationConstraint=${AWS_REGION}"
    fi
fi

aws s3api put-bucket-versioning \
    --bucket "${TF_STATE_BUCKET}" \
    --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
    --bucket "${TF_STATE_BUCKET}" \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          },
          "BucketKeyEnabled": true
        }
      ]
    }'

aws s3api put-public-access-block \
    --bucket "${TF_STATE_BUCKET}" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-ownership-controls \
    --bucket "${TF_STATE_BUCKET}" \
    --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

echo "state bucket ${TF_STATE_BUCKET} is ready in ${AWS_REGION}"
