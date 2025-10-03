# Carian Constellation - Bootstrap Infrastructure
# One-time setup for persistent resources

terraform {
  required_version = ">= 1.5"
  
  # Local backend for bootstrap (chicken-egg problem)
  # After this runs, ephemeral module will use S3 backend
  backend "local" {
    path = "terraform.tfstate"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project            = "CarianConstellation"
      ManagedBy          = "Terraform"
      TerraformPath      = "terraform/bootstrap"
      Environment        = "persistent"
      Lifecycle          = "permanent"
      Owner              = var.owner_name
      OwnerEmail         = var.owner_email
      CostCenter         = "personal-projects"
      SecurityZone       = "restricted"
      DataClassification = "personal"
    }
  }
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# Get AWS region
data "aws_region" "current" {}

# Random suffix for global uniqueness
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Unique naming
  project_prefix = "carian-constellation"
  unique_suffix  = random_id.suffix.hex
  
  # Common tags
  common_tags = {
    Project            = "CarianConstellation"
    Repository         = "github.com/${var.github_username}/carian-constellation"
    ManagedBy          = "Terraform"
    TerraformPath      = "terraform/bootstrap"
    Environment        = "persistent"
    Owner              = var.owner_name
    OwnerEmail         = var.owner_email
    CostCenter         = "personal-projects"
    BillingTeam        = var.owner_name
    SecurityZone       = "restricted"
    DataClassification = "personal"
    BackupPolicy       = "retain"
  }
}
