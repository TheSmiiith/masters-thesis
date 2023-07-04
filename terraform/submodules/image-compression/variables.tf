# Inherited variables
variable "vpc_id" {}
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }

variable "project_name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "image_store_queue_url" {
  type = string
}

variable "temporary_image_store_bucket_name" {
  type = string
}

# EC2
variable "image_compression_ami" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 1
}

variable "auto_scaling_policy_enabled" {
  type    = bool
  default = true
}

# ECS
variable "ecs_cluster_id" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_desired_capacity" {
  type = number
}

variable "ecs_min_capacity" {
  type = number
}

variable "ecs_max_capacity" {
  type = number
}

variable "ecs_cpu" {
  type = number
}

variable "ecs_memory" {
  type = number
}

variable "ecs_cluster_cloudwatch_log_group_name" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_auto_scaling_policy_enabled" {
  type = bool
}

# Lambda
variable "lambda_enabled" {
  type = bool
}

variable "lambda_memory" {
  type = number
}