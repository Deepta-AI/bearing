resource "aws_cloudwatch_log_group" "app" {
  name = "/orders/app"
  tags = { env = "prod", service = "orders-api" }
}

resource "aws_cloudwatch_log_group" "app_qa" {
  name              = "/orders/app-qa"
  retention_in_days = 14
  tags              = { env = "qa", service = "orders-api" }
}

# ADR-0004: 400 days, do not lower without legal sign-off.
resource "aws_cloudwatch_log_group" "audit" {
  name              = "/orders/audit"
  retention_in_days = 400
  tags              = { env = "prod", service = "orders-api" }
}
