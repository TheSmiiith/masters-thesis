data "archive_file" "lambda_zip" {
  type             = "zip"
  source_file      = "${path.module}/../../../application/image-effecting-service/main_lambda.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/bin/main_lambda.zip"
}

resource "aws_lambda_function" "image_effecting_lambda" {
  function_name = "image-effecting-lambda"
  description   = "Image Effecting Lambda Function"

  role = aws_iam_role.image_effecting_role.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "main_lambda.lambda_handler"

  runtime = "python3.10"
  layers  = ["arn:aws:lambda:eu-central-1:770693421928:layer:Klayers-p310-Pillow:2"]
  timeout = 300

  memory_size = var.lambda_memory

  environment {
    variables = {
      QUEUE_URL                         = aws_sqs_queue.image_effecting_queue.url
      IMAGE_STORE_QUEUE_URL             = var.image_store_queue_url
      TEMPORARY_IMAGE_STORE_BUCKET_NAME = var.temporary_image_store_bucket_name
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.image_effecting_instance_security_group.id]
  }

  tags = {
    Project = var.project_name
    Name    = "Image Effecting Lambda Function"
  }
}

resource "aws_lambda_event_source_mapping" "image_effecting_lambda_event_source_mapping" {
  enabled = var.lambda_enabled

  event_source_arn                   = aws_sqs_queue.image_effecting_queue.arn
  function_name                      = aws_lambda_function.image_effecting_lambda.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
}