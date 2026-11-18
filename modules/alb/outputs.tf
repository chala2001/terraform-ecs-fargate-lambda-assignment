# Values the ECS and Lambda modules need

output "alb_dns_name" {
  description = "Public DNS name of the ALB (used to call the API)"
  value       = aws_lb.this.dns_name
}

output "alb_security_group_id" {
  description = "ALB SG; ECS tasks only accept traffic from this SG"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target group where ECS registers tasks"
  value       = aws_lb_target_group.app.arn
}