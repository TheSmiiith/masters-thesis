# Output variables
output "queue_url" {
  description = "Image Effecting SQS Queue URL"
  value       = aws_sqs_queue.image_effecting_queue.url
}