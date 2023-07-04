# Output variables
output "queue_url" {
  description = "Image Compression SQS Queue URL"
  value       = aws_sqs_queue.image_compression_queue.url
}