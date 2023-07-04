resource "aws_iam_instance_profile" "image_store_instance_profile" {
  name = "image_store_instance_profile"
  role = aws_iam_role.image_store_role.name
}

resource "aws_cloudwatch_log_group" "image_store_lg" {
  name = "/aws/ec2/masters-thesis/image-store-service"

  tags = {
    Project = var.project_name
    Name    = "Image Store Service Log Group"
  }
}

resource "aws_launch_template" "image_store_lt" {
  name          = "image_store_launch_template"
  image_id      = var.image_store_ami
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.image_store_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.image_store_instance_security_group.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo su - ubuntu
              echo "AWS_REGION=${var.aws_region}" >> /etc/environment
              echo "QUEUE_URL=${aws_sqs_queue.image_store_queue.url}" >> /etc/environment
              echo "IMAGE_COMPRESSION_QUEUE_URL=${var.image_compression_queue_url}" >> /etc/environment
              echo "IMAGE_EFFECTING_QUEUE_URL=${var.image_effecting_queue_url}" >> /etc/environment
              echo "TEMPORARY_IMAGE_STORE_BUCKET_NAME=${var.temporary_image_store_bucket_name}" >> /etc/environment
              echo "IMAGE_STORE_DATABASE_ADDRESS=${aws_rds_cluster.image_store_database_cluster.endpoint}" >> /etc/environment
              echo "IMAGE_STORE_DATABASE_NAME=${var.image_store_database_name}" >> /etc/environment
              echo "IMAGE_STORE_DATABASE_USER=${var.image_store_database_user}" >> /etc/environment
              echo "IMAGE_STORE_DATABASE_PASSWORD=${var.image_store_database_password}" >> /etc/environment
              sudo systemctl start image-store-service
              EOF
  )

  depends_on = [
    aws_cloudwatch_log_group.image_store_lg,
    aws_rds_cluster.image_store_database_cluster,
    aws_rds_cluster_instance.aurora_instances
  ]
}

resource "aws_autoscaling_group" "image_store_asg" {
  name = "Image Store Auto Scaling Group"

  min_size         = var.min_capacity
  desired_capacity = var.desired_capacity
  max_size         = var.max_capacity

  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = [aws_lb_target_group.image_store_lb_tg.arn]

  default_cooldown = 0

  launch_template {
    id      = aws_launch_template.image_store_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "Image Store Service Instance"
    propagate_at_launch = true
  }
}

resource "aws_lb" "image_store_lb" {
  name               = "image-store-load-balancer"
  load_balancer_type = "application"
  internal           = false

  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.image_store_load_balancer_security_group.id]

  idle_timeout = 500

  tags = {
    Project = var.project_name
    Name    = "Image Store Service Load Balancer"
  }
}

resource "aws_lb_target_group" "image_store_lb_tg" {
  name     = "image-store-load-balancer-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    matcher             = "200"
    path                = "/health-check"
    port                = "3000"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Project = var.project_name
    Name    = "Image Store Service Load Balancer Target Group"
  }
}

resource "aws_lb_listener" "image_store_lb_listener" {
  load_balancer_arn = aws_lb.image_store_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.image_store_lb_tg.arn
  }

  tags = {
    Project = var.project_name
    Name    = "Image Store Service Load Balancer Listener"
  }
}

resource "aws_autoscaling_policy" "image_store_asg_scale_up" {
  enabled = var.auto_scaling_policy_enabled

  name                   = "image_store_asg_scale_up"
  autoscaling_group_name = aws_autoscaling_group.image_store_asg.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 0
}

resource "aws_cloudwatch_metric_alarm" "image_store_asg_cpu_high_alarm" {
  actions_enabled = var.auto_scaling_policy_enabled

  alarm_name          = "image_store_asg_cpu_high_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "This metric triggers when CPU exceeds 40%"
  alarm_actions       = [aws_autoscaling_policy.image_store_asg_scale_up.arn]
  dimensions          = {
    AutoScalingGroupName = aws_autoscaling_group.image_store_asg.name
  }
}

resource "aws_autoscaling_policy" "image_store_asg_scale_down" {
  enabled = var.auto_scaling_policy_enabled

  name                   = "image_store_asg_scale_down"
  autoscaling_group_name = aws_autoscaling_group.image_store_asg.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 0
}

resource "aws_cloudwatch_metric_alarm" "image_store_asg_cpu_low_alarm" {
  actions_enabled = var.auto_scaling_policy_enabled

  alarm_name          = "image_store_asg_cpu_low_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric triggers when CPU drops below 20%"
  alarm_actions       = [aws_autoscaling_policy.image_store_asg_scale_down.arn]
  dimensions          = {
    AutoScalingGroupName = aws_autoscaling_group.image_store_asg.name
  }
}