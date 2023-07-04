resource "aws_security_group" "image_compression_instance_security_group" {
  name_prefix = "image_compression_instance_security_group"

  vpc_id = var.vpc_id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
    Name    = "Image Compression Service Instance Security Group"
  }
}