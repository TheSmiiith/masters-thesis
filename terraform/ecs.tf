resource "aws_cloudwatch_log_group" "ecs_cluster_lg" {
  name = "/aws/ecs/masters-thesis"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "masters-thesis-cluster"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_cluster_lg.name
      }
    }
  }

  tags = {
    Project = var.project_name
    Name    = "Masters Thesis ECS Cluster"
  }
}