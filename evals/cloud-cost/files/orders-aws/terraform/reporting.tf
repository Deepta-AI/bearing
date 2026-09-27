# Nightly reporting batch, see docs/runbooks/reporting.md.
resource "aws_instance" "reporting" {
  ami           = "ami-0reporting2025"
  instance_type = "m5.4xlarge"
  subnet_id     = aws_subnet.private[0].id
  tags          = { Name = "reporting-batch" }
}
