terraform {
  required_version = ">= 0.13.0"

  required_providers {
    # v5 blocked until https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn/pull/280
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9.0, < 6.0.0"
    }
  }
}
