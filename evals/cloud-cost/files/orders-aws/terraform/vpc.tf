resource "aws_vpc" "main" {
  cidr_block = "10.40.0.0/16"
  tags       = { env = "prod", service = "network" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.40.0.0/16", 4, count.index)
  availability_zone = ["ap-south-1a", "ap-south-1b"][count.index]
}

resource "aws_nat_gateway" "az" {
  count         = 2
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
  tags          = { env = "prod", service = "network" }
}

# Gateway endpoint for S3 only. Everything else the pods call on AWS
# (CloudWatch Logs, ECR, STS) goes out through the NAT gateways.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"
}
