# TFLint configuration for Carian Constellation
# https://github.com/terraform-linters/tflint

config {
  module = true
  force = false
}

# AWS Plugin
plugin "aws" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Terraform Plugin
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-specific rules
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_instance_previous_type" {
  enabled = true
}

rule "aws_s3_bucket_versioning_enabled" {
  enabled = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags = [
    "Owner",
    "Project",
    "Environment",
    "ManagedBy",
    "Lifecycle"
  ]
}

# Terraform best practices
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

# Security rules
rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false  # Not applicable for non-GovCloud
}

rule "aws_iam_role_policy_too_permissive" {
  enabled = true
}

rule "aws_s3_bucket_public_access_block" {
  enabled = true
}

rule "aws_security_group_allows_all_traffic" {
  enabled = true
}

# Cost optimization rules
rule "aws_db_instance_default_parameter_group" {
  enabled = true
}

rule "aws_instance_default_ami" {
  enabled = true
}

# Networking rules
rule "aws_route_not_specified_target" {
  enabled = true
}

rule "aws_route_specified_multiple_targets" {
  enabled = true
}

# EKS-specific (custom validation via terraform validate)
# These would need custom rules or external validation
