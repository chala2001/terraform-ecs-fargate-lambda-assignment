output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "log_group_name" {
  description = "Where the health check results are logged"
  value       = aws_cloudwatch_log_group.this.name
}