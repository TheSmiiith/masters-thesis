variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "aws_code_commit_repository_arn" {
  description = "masters-thesis CodeCommit repository arn"
  type        = string
  default     = "arn:aws:iam::219160904422:policy/allow_pull_from_masters_thesis_code_commit_repository"
}

variable "project_name" {
  description = "Project name for _project_ tag"
  type        = string
  default     = "masters-thesis"
}