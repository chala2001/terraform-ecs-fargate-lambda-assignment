# ---------- Logs ----------

# Container stdout/stderr goes here; short retention keeps cost near zero
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_days
}

# ---------- Cluster ----------

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  # Container Insights costs extra; disabled for this learning project
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

# ---------- IAM roles ----------

# Trust policy shared by both roles: only the ECS tasks service can assume them
locals {
  ecs_tasks_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Execution role: used by ECS to START the task (pull image, write logs)
resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-ecs-execution-role"
  assume_role_policy = local.ecs_tasks_trust
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: used by the APP code. Our app calls no AWS APIs → no policies (least privilege)
resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = local.ecs_tasks_trust
}

# ---------- Task security group ----------

resource "aws_security_group" "task" {
  name        = "${var.name_prefix}-task-sg"
  description = "ECS tasks: app port only from the ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-task-sg" }
}

# Inbound: ONLY from the ALB's security group (not from any IP range)
resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "App port from ALB only"
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

# Outbound: all (via NAT) to pull the image and send logs
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.task.id
  description       = "All outbound via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- Task definition: the recipe ----------

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Each task gets its own private IP (required for Fargate)
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "api"
    image     = var.container_image
    essential = true
    user      = "nobody" # Do not run as root

    portMappings = [{ containerPort = var.app_port, protocol = "tcp" }]

    # V1: decode the app code from the env var and run it (V2 will bake it into our own image)
    command = ["python", "-c", "import os,base64; exec(base64.b64decode(os.environ['APP_CODE']))"]

    environment = [
      { name = "APP_PORT", value = tostring(var.app_port) },
      { name = "APP_CODE", value = base64encode(var.app_code) }
    ]

    # Send container output to CloudWatch Logs
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "api"
      }
    }
  }])
}

# ---------- Service: keeps tasks running and connects them to the ALB ----------

resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Tasks run in PRIVATE subnets with NO public IP
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  # Register each task's IP in the ALB target group
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api"
    container_port   = var.app_port
  }

  # If a new deployment keeps failing, stop and roll back automatically
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  propagate_tags = "SERVICE" # Running tasks also get the service's tags
}