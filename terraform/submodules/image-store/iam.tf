resource "aws_iam_role" "image_store_role" {
  name = "image_store_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = ""
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "image_store_policies"

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
          Sid      = "RDSFullAccess",
          Effect   = "Allow",
          Action   = "rds:*",
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
        }
      ]
    })
  }

  tags = {
    Project = var.project_name
    Name    = "Image Store IAM Role"
  }
}