############################################################
# Providers and backend configuration
# - Pins provider versions
# - Configures default + us-east-1 AWS providers
# - Stores state in S3
############################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }
  }
}

#############################################
# Default AWS provider for all primary resources.
# Uses the region defined in variables and the "personal" profile.

provider "aws" {
  region  = var.aws_region
  profile = "personal"
}

#############################################
# Secondary AWS provider for resources that MUST be created in us-east-1.
# Required for CloudFront ACM certificates and any global services bound to this region.

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "personal"
}

#############################################
#for remotely maintaining state

terraform {
  backend "s3" {
    bucket  = "chris-nelson-terraform-state"
    key     = "chris-nelson-dev-be/terraform.tfstate"
    region  = "us-east-1"
    profile = "personal"
    #dynamodb_table = "terraform-locks" # maybe later
  }
}

#############################################
