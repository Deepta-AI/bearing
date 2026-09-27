resource "aws_db_instance" "orders_prod" {
  identifier              = "orders-db-prod"
  engine                  = "postgres"
  instance_class          = "db.r6g.2xlarge"
  multi_az                = true
  allocated_storage       = 1000
  storage_type            = "gp3"
  backup_retention_period = 14
  tags                    = { env = "prod", service = "orders-db" }
}

resource "aws_db_instance" "orders_qa" {
  identifier        = "orders-db-qa"
  engine            = "postgres"
  instance_class    = "db.r6g.large"
  allocated_storage = 200
  storage_type      = "gp3"
  tags              = { env = "qa", service = "orders-db" }
}

resource "aws_db_instance" "orders_dev" {
  identifier        = "orders-db-dev"
  engine            = "postgres"
  instance_class    = "db.t4g.large"
  allocated_storage = 50
  tags              = { env = "dev", service = "orders-db" }
}
