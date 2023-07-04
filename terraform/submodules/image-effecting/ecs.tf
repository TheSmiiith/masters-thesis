data "aws_ecr_repository" "image_effecting_ecr_repository" {
  name = "image-effecting-service"
}

resource "aws_ecs_task_definition" "image_effecting_ecs_task_definition" {
  family = "image-effecting"

  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  cpu    = var.ecs_cpu
  memory = var.ecs_memory

  task_role_arn      = aws_iam_role.image_effecting_role.arn
  execution_role_arn = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      essential = true
      name      = "image-effecting-container"
      image     = "${data.aws_ecr_repository.image_effecting_ecr_repository.repository_url}:latest"

      cpu    = var.ecs_cpu
      memory = var.ecs_memory

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "QUEUE_URL"
          value = aws_sqs_queue.image_effecting_queue.url
        },
        {
          name  = "IMAGE_STORE_QUEUE_URL"
          value = var.image_store_queue_url
        },
        {
          name  = "TEMPORARY_IMAGE_STORE_BUCKET_NAME"
          value = var.temporary_image_store_bucket_name
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          "awslogs-region"        = var.aws_region
          "awslogs-group"         = var.ecs_cluster_cloudwatch_log_group_name
          "awslogs-stream-prefix" = "image-effecting-ecs-container"
        }
      }
    }
  ])

  tags = {
    Project = var.project_name
    Name    = "Image Effecting ECS Task Definition"
  }
}

resource "aws_ecs_service" "image_effecting_ecs_service" {
  name    = "image-effecting-service"
  cluster = var.ecs_cluster_id

  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.image_effecting_ecs_task_definition.arn

  desired_count = var.ecs_desired_capacity

  network_configuration {
    subnets = var.private_subnet_ids
  }

  tags = {
    Project = var.project_name
    Name    = "Image Effecting ECS service"
  }
}

resource "aws_appautoscaling_target" "image_effecting_autoscaling_target" {
  min_capacity       = var.ecs_min_capacity
  max_capacity       = var.ecs_max_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.image_effecting_ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "image_effecting_autoscaling_policy" {
  count              = var.ecs_auto_scaling_policy_enabled ? 1 : 0
  name               = "image_effecting_autoscaling_policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.image_effecting_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.image_effecting_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.image_effecting_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 40
    scale_in_cooldown  = 0
    scale_out_cooldown = 0
  }

  lifecycle { ignore_changes = all }
}