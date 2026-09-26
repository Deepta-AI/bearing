resource "aws_db_parameter_group" "ledger" {
  name   = "ledger-prod-pg15"
  family = "postgres15"

  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "ledger" {
  identifier              = "ledger-prod"
  engine                  = "postgres"
  engine_version          = "15.5"
  instance_class          = "db.r6g.large"
  allocated_storage       = 200
  multi_az                = false
  backup_retention_period = 7
  backup_window           = "20:00-21:00"
  parameter_group_name    = aws_db_parameter_group.ledger.name
  deletion_protection     = true
}
