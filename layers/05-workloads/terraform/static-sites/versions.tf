terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # bucket and region are supplied at init time:
  #   terraform init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="region=$AWS_REGION"
  # The backend region is the state bucket's region (us-east-1). Site buckets
  # use var.aws_region (eu-central-1) and do not follow AWS_REGION.
  backend "s3" {
    key          = "05-workloads/static-sites/prod.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
