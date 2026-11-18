output "api_url" {
  description = "Call the API through the ALB"
  value       = "http://${module.alb.alb_dns_name}"
}


output "lambda_function_name" {
  description = "Health checker function name"
  value       = module.lambda.function_name
}