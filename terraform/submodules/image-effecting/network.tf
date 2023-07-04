resource "aws_security_group" "image_effecting_instance_security_group" {
  name_prefix = "image_effecting_instance_security_group"

  vpc_id = var.vpc_id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
    Name    = "Image Effecting Service Instance Security Group"
  }
}