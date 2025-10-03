# Variables for Bootstrap Infrastructure

variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Your domain name (e.g., example.com)"
  type        = string
}

variable "owner_name" {
  description = "Owner name for resource tagging"
  type        = string
  default     = "stalheim"
}

variable "owner_email" {
  description = "Owner email for resource tagging"
  type        = string
}

variable "github_username" {
  description = "GitHub username for repository tagging"
  type        = string
}

variable "enable_s3_versioning" {
  description = "Enable versioning on S3 buckets"
  type        = bool
  default     = true
}

variable "terraform_state_retention_days" {
  description = "Number of days to retain old Terraform state versions"
  type        = number
  default     = 90
}

variable "backup_retention_days" {
  description = "Number of days to retain backups in S3"
  type        = number
  default     = 30
}
