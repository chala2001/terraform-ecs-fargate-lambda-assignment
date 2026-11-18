
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for the ALB)"
  value       = aws_subnet.public[*].id # [*] = list of all IDs
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for ECS tasks and Lambda)"
  value       = aws_subnet.private[*].id
}



output "vpc_cidr" {
  description = "CIDR of the VPC (used to limit ALB outbound traffic)"
  value       = aws_vpc.this.cidr_block
}