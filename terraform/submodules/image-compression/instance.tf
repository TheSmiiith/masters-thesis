resource "aws_iam_instance_profile" "image_compression_instance_profile" {
  name = "image_compression_instance_profile"
  role = aws_iam_role.image_compression_role.name
}

resource "aws_cloudwatch_log_group" "image_compression_lg" {
  name = "/aws/ec2/masters-thesis/image-compression-service"

  tags = {
    Project = var.project_name
    Name    = "Image Compression Service Log Group"
  }
}

resource "aws_launch_template" "image_compression_lt" {
  name          = "image_compression_launch_configuration"
  image_id      = var.image_compression_ami
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.image_compression_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.image_compression_instance_security_group.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo su - ubuntu
              echo "AWS_REGION=${var.aws_region}" >> /etc/environment
              echo "QUEUE_URL=${aws_sqs_queue.image_compression_queue.url}" >> /etc/environment
              echo "IMAGE_STORE_QUEUE_URL=${var.image_store_queue_url}" >> /etc/environment
              echo "TEMPORARY_IMAGE_STORE_BUCKET_NAME=${var.temporary_image_store_bucket_name}" >> /etc/environment
              sudo systemctl start image-compression-service
              EOF
  )

  depends_on = [
    aws_cloudwatch_log_group.image_compression_lg,
  ]
}

resource "aws_autoscaling_group" "image_compression_asg" {
  name = "Image Compression Auto Scaling Group"

  min_size         = var.min_capacity
  desired_capacity = var.desired_capacity
  max_size         = var.max_capacity

  vpc_zone_identifier = var.private_subnet_ids

  default_cooldown = 0

  launch_template {
    id      = aws_launch_template.image_compression_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "Image Compression Service Instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "image_compression_asg_scale_up" {
  enabled = var.auto_scaling_policy_enabled

  name                   = "image_compression_asg_scale_up"
  autoscaling_group_name = aws_autoscaling_group.image_compression_asg.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 0
}

resource "aws_cloudwatch_metric_alarm" "image_compression_asg_cpu_high_alarm" {
  actions_enabled = var.auto_scaling_policy_enabled

  alarm_name          = "image_compression_asg_cpu_high_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "This metric triggers when CPU exceeds 40%"
  alarm_actions       = [aws_autoscaling_policy.image_compression_asg_scale_up.arn]
  dimensions          = {
    AutoScalingGroupName = aws_autoscaling_group.image_compression_asg.name
  }
}

resource "aws_autoscaling_policy" "image_compression_asg_scale_down" {
  enabled = var.auto_scaling_policy_enabled

  name                   = "image_compression_asg_scale_down"
  autoscaling_group_name = aws_autoscaling_group.image_compression_asg.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 0
}

resource "aws_cloudwatch_metric_alarm" "image_compression_asg_cpu_low_alarm" {
  actions_enabled = var.auto_scaling_policy_enabled

  alarm_name          = "image_compression_asg_cpu_low_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric triggers when CPU drops below 20%"
  alarm_actions       = [aws_autoscaling_policy.image_compression_asg_scale_down.arn]
  dimensions          = {
    AutoScalingGroupName = aws_autoscaling_group.image_compression_asg.name
  }
}
