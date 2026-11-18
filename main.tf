# Names and AZs reused everywhere
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = ["${var.aws_region}a", "${var.aws_region}b"] # 2 AZs (ALB needs at least 2)
}

# Network: VPC, public + private subnets in 2 AZs, IGW, NAT, routing
module "network" {
  source = "./modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = "10.0.0.0/16"
  azs                  = local.azs
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
}



# ALB: public entry point that forwards to ECS tasks in private subnets
module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  public_subnet_ids = module.network.public_subnet_ids
  app_port          = var.app_port
  allowed_cidr      = var.allowed_cidr
}





# ECS: Fargate service running the API in private subnets behind the ALB
module "ecs" {
  source = "./modules/ecs"

  name_prefix           = local.name_prefix
  aws_region            = var.aws_region
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  app_port              = var.app_port
  container_image       = "public.ecr.aws/docker/library/python:3.12-slim"
  app_code              = file("${path.root}/app/app.py")

  # The target group must be attached to the ALB listener before the service uses it
  depends_on = [module.alb]
}



# Lambda: scheduled health checker running in private subnets
module "lambda" {
  source = "./modules/lambda"

  name_prefix        = local.name_prefix
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  source_file        = "${path.root}/lambda/handler.py"
  target_url         = "http://${module.alb.alb_dns_name}/health"
}