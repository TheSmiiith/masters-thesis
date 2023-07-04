# Output variables
output "queue_url" {
  description = "Image Store SQS Queue URL"
  value       = aws_sqs_queue.image_store_queue.url
}