terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.62"
    }
  }
}

locals {
  # Switch Infrastructure: ec2/ecs/lambda/none
  active_infra = "ec2"
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_s3_bucket" "temporary_image_store_bucket" {
  bucket_prefix = "temporary-image-store-"

  # Enable force destroy (delete the bucket even if is not empty on terraform destroy)
  force_destroy = true

  tags = {
    Project = var.project_name
    Name    = "Temporary Image Store S3 Bucket"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "temporary_image_store_bucket_lifecycle" {
  bucket = aws_s3_bucket.temporary_image_store_bucket.id

  rule {
    id     = "delete_files_older_than_1_day"
    status = "Enabled"

    expiration {
      days = 1
    }
  }
}

module "image-compression" {
  source = "./submodules/image-compression"

  # VPC
  vpc_id             = aws_vpc.main.id
  public_subnet_ids  = aws_subnet.public[*].id
  private_subnet_ids = aws_subnet.private[*].id

  # Module variables
  project_name                      = var.project_name
  temporary_image_store_bucket_name = aws_s3_bucket.temporary_image_store_bucket.id
  image_store_queue_url             = module.image-store.queue_url

  # EC2
  image_compression_ami       = "ami-0994182ff2eac9378"
  instance_type               = "c6i.large"
  min_capacity                = local.active_infra == "ec2" ? 1 : 0
  desired_capacity            = local.active_infra == "ec2" ? 1 : 0
  max_capacity                = local.active_infra == "ec2" ? 5 : 0
  auto_scaling_policy_enabled = true

  # ECS
  ecs_cluster_id                        = aws_ecs_cluster.ecs_cluster.id
  ecs_cluster_name                      = aws_ecs_cluster.ecs_cluster.name
  ecs_cluster_cloudwatch_log_group_name = aws_cloudwatch_log_group.ecs_cluster_lg.name
  ecs_min_capacity                      = local.active_infra == "ecs" ? 1 : 0
  ecs_desired_capacity                  = local.active_infra == "ecs" ? 1 : 0
  ecs_max_capacity                      = local.active_infra == "ecs" ? 5 : 0
  ecs_cpu                               = 2048
  ecs_memory                            = 4096
  ecs_execution_role_arn                = aws_iam_role.ecs_execution_role.arn
  ecs_auto_scaling_policy_enabled       = true

  # Lambda
  lambda_enabled = local.active_infra == "lambda" ? true : false
  lambda_memory  = 2048
}

module "image-effecting" {
  source = "./submodules/image-effecting"

  # VPC
  vpc_id             = aws_vpc.main.id
  public_subnet_ids  = aws_subnet.public[*].id
  private_subnet_ids = aws_subnet.private[*].id

  # Module variables
  project_name                      = var.project_name
  temporary_image_store_bucket_name = aws_s3_bucket.temporary_image_store_bucket.id
  image_store_queue_url             = module.image-store.queue_url

  # EC2
  image_effecting_ami         = "ami-06ae83db77abf5b57"
  instance_type               = "c6i.large"
  min_capacity                = local.active_infra == "ec2" ? 3 : 0
  desired_capacity            = local.active_infra == "ec2" ? 3 : 0
  max_capacity                = local.active_infra == "ec2" ? 20 : 0
  auto_scaling_policy_enabled = true

  # ECS
  ecs_cluster_id                        = aws_ecs_cluster.ecs_cluster.id
  ecs_cluster_name                      = aws_ecs_cluster.ecs_cluster.name
  ecs_cluster_cloudwatch_log_group_name = aws_cloudwatch_log_group.ecs_cluster_lg.name
  ecs_min_capacity                      = local.active_infra == "ecs" ? 4 : 0
  ecs_desired_capacity                  = local.active_infra == "ecs" ? 4 : 0
  ecs_max_capacity                      = local.active_infra == "ecs" ? 20 : 0
  ecs_cpu                               = 2048
  ecs_memory                            = 4096
  ecs_execution_role_arn                = aws_iam_role.ecs_execution_role.arn
  ecs_auto_scaling_policy_enabled       = true

  # Lambda
  lambda_enabled = local.active_infra == "lambda" ? true : false
  lambda_memory  = 2048
}

module "image-store" {
  source = "./submodules/image-store"

  # VPC
  vpc_id             = aws_vpc.main.id
  public_subnet_ids  = aws_subnet.public[*].id
  private_subnet_ids = aws_subnet.private[*].id

  # Module variables
  project_name                      = var.project_name
  aws_region                        = var.aws_region
  temporary_image_store_bucket_name = aws_s3_bucket.temporary_image_store_bucket.id

  image_compression_queue_url = module.image-compression.queue_url
  image_effecting_queue_url   = module.image-effecting.queue_url

  # EC2
  image_store_ami             = "ami-0763482fce692d840"
  instance_type               = "c6i.2xlarge"
  min_capacity                = 1
  desired_capacity            = 1
  max_capacity                = 1
  auto_scaling_policy_enabled = false

  # RDS
  database_instance_type  = "db.t4g.medium"
  database_instance_count = 1
}