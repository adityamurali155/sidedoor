locals {
  interface_endpoint_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
    "secretsmanager",
    "ecr.api",
    "ecr.dkr",
    "ecs",            # ← new
    "ecs-agent",      # ← new
    "ecs-telemetry",  # ← new
    "logs",
  ]
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each            = toset(local.interface_endpoint_services)
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.app_subnet.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "challenge-${each.value}-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.target_private.id]

  tags = {
    Name = "${var.challenge_name}-s3-gateway-endpoint"
  }
}