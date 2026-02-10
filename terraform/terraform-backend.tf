# Terraform Backend Configuration
# S3 backend for state storage with DynamoDB for state locking

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # These values are provided via -backend-config flags during terraform init
    # in the GitHub Actions workflow:
    # 
    # bucket         = "terraform-state-sre-monitoring"
    # key            = "sre-monitoring-dev.tfstate"
    # region         = "us-east-2"
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}

# Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "SRE-Monitoring"
      Environment = var.environment
    }
  }
}