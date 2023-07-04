resource "aws_sqs_queue" "image_compression_queue" {
  name = "image_compression_queue"

  delay_seconds = 0

  # Automatically delete messages after 300 seconds
  visibility_timeout_seconds = 300

  sqs_managed_sse_enabled = true

  tags = {
    Project = var.project_name
    Name    = "Image Compression Queue"
  }
}