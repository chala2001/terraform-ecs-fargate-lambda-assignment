locals {
  function_name = "${var.name_prefix}-health-checker"
}

# ---------- Package the code ----------

# Zip the Python file; this runs on your laptop during plan/apply
data "archive_file" "zip" {
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.root}/build/health_checker.zip"
}

# ---------- Logs ----------

# Created BEFORE the function so our retention setting applies
# (Lambda would otherwise create it automatically with "never expire")
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

# ---------- IAM ----------

# Role that only the Lambda service can assume
resource "aws_iam_role" "this" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# AWS managed policy: write logs + create network interfaces in the VPC
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ---------- Security group ----------

# No inbound rules at all: nothing ever connects TO the Lambda
resource "aws_security_group" "this" {
  name        = "${local.function_name}-sg"
  description = "Lambda: outbound only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.function_name}-sg" }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound via NAT to call the ALB"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- Function ----------

resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  role             = aws_iam_role.this.arn
  runtime          = "python3.13"
  handler          = "handler.lambda_handler" # file.function
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256 # Redeploy when code changes
  timeout          = 10
  memory_size      = 128 # Smallest size; enough for one HTTP call

  # Run inside the PRIVATE subnets (no public IP)
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  environment {
    variables = {
      TARGET_URL = var.target_url
    }
  }

  depends_on = [aws_cloudwatch_log_group.this, aws_iam_role_policy_attachment.vpc_access]
}

# ---------- Schedule ----------

# EventBridge rule: fires every 5 minutes
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${local.function_name}-schedule"
  description         = "Run the health checker on a schedule"
  schedule_expression = var.schedule_expression
}

# Target: what the rule triggers → our Lambda
resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.this.arn
}

# Permission: allow ONLY this EventBridge rule to invoke the function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}