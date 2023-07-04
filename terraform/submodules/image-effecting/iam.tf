resource "aws_iam_role" "image_effecting_role" {
  name = "image_effecting_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = ""
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com", "lambda.amazonaws.com", "ecs-tasks.amazonaws.com"]
        }
      }
    ]
  })

  inline_policy {
    name = "image_effecting_policies"

    policy = jsonencode({
      Version   = "2012-10-17",
      Statement = [
        {
          Sid      = "S3FullAccess",
          Effect   = "Allow",
          Action   = "s3:*",
          Resource = "*"
        },
        {
          Sid      = "SQSFullAccess",
          Effect   = "Allow",
          Action   = "sqs:*",
          Resource = "*"
        },
        {
          Sid      = "CloudWatchLogsFullAccess",
          Effect   = "Allow",
          Action   = "logs:*",
          Resource = "*"
        },
        {
          Sid      = "AmazonEC2FullAccess",
          Effect   = "Allow",
          Action   = "ec2:*",
          Resource = "*"
        }
      ]
    })
  }

  tags = {
    Project = var.project_name
    Name    = "Image Effecting IAM Role"
  }
}