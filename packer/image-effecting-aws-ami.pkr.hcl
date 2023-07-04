packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.5"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_access_key" {
  type = string
  sensitive = true
}

variable "aws_secret_key" {
  type = string
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "aws_source_ami" {
  type = string
}

variable "aws_instance_type" {
  type = string
}

source "amazon-ebs" "ebs" {
  # AWS config
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.aws_region

  # Source AMI
  source_ami = var.aws_source_ami

  # Instance config
  instance_type = var.aws_instance_type
  ssh_username = "ubuntu"

  # Output AMI
  ami_name = "Image Effecting AMI - {{timestamp}}"

  # Tags
  tags = {
    "Name" = "Image Effecting AMI - {{timestamp}}"
    "Project" = "masters-thesis"
  }
}

build {
  # Build name
  name = "image-effecting"

  # Sources
  sources = [
    "source.amazon-ebs.ebs"
  ]

  # Provisioner
  provisioner "shell" {
    environment_vars = [
      "AWS_DEFAULT_REGION=${var.aws_region}",
      "AWS_ACCESS_KEY_ID=${var.aws_access_key}",
      "AWS_SECRET_ACCESS_KEY=${var.aws_secret_key}",
    ]
    script = "../application/image-effecting-service/install.sh"
  }
}