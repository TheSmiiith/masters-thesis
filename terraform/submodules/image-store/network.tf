resource "aws_security_group" "image_store_instance_security_group" {
  name_prefix = "image_store_instance_security_group"

  vpc_id = var.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
    Name    = "Image Store Service Instance Security Group"
  }
}

resource "aws_security_group" "image_store_database_security_group" {
  name_prefix = "image_store_database_security_group"

  vpc_id = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
    Name    = "Image Store Service Database Security Group"
  }
}

resource "aws_security_group" "image_store_load_balancer_security_group" {
  name_prefix = "image_store_load_balancer_security_group"

  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
    Name    = "Image Store Service Load Balancer Security Group"
  }
}