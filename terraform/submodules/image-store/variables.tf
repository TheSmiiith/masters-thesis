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

variable "image_compression_queue_url" {
  type = string
}

variable "image_effecting_queue_url" {
  type = string
}

variable "temporary_image_store_bucket_name" {
  type = string
}

# Module variables
variable "image_store_ami" {
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

variable "database_instance_type" {
  type    = string
  default = "db.t3.medium"
}

variable "database_instance_count" {
  type    = number
  default = 1
}

variable "image_store_database_name" {
  description = "Image Store Database database name"
  type        = string
  sensitive   = true
  default     = "image_store_database"
}

variable "image_store_database_user" {
  description = "Image Store Database user name"
  type        = string
  sensitive   = true
  default     = "image_store_database_user"
}

variable "image_store_database_password" {
  description = "Image Store Database password"
  type        = string
  sensitive   = true
  default     = "image_store_database_password"
}

variable "auto_scaling_policy_enabled" {
  type    = bool
  default = true
}