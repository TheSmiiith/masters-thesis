resource "aws_rds_cluster" "image_store_database_cluster" {
  cluster_identifier = "image-store-database-cluster"

  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.02.2"

  database_name   = var.image_store_database_name
  master_username = var.image_store_database_user
  master_password = var.image_store_database_password

  db_subnet_group_name   = aws_db_subnet_group.aurora_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.image_store_database_security_group.id]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = {
    Project = var.project_name
    Name    = "Image Store Database Cluster"
  }
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = var.database_instance_count
  identifier         = "image-store-database-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.image_store_database_cluster.id

  instance_class = var.database_instance_type

  engine         = aws_rds_cluster.image_store_database_cluster.engine
  engine_version = aws_rds_cluster.image_store_database_cluster.engine_version

  db_subnet_group_name = aws_db_subnet_group.aurora_db_subnet_group.name

  tags = {
    Project = var.project_name
    Name    = "Image Store Database Instance"
  }
}

resource "aws_db_subnet_group" "aurora_db_subnet_group" {
  name       = "aurora-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Project = var.project_name
    Name    = "Image Store Database Subnet Group"
  }
}