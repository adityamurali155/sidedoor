resource "aws_security_group" "app_sg" {
  name        = "${var.challenge_name}-app-sg"
  description = "App server - only reachable via ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.challenge_name}-app-sg"
    Purpose = "cseccon-challenge"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "challenge-alb-sg"
  description = "Allows inbound HTTP from players"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from players"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "cseccon-alb-sg"
    Purpose = "cseccon-challenge"
  }
}
resource "aws_security_group" "vpc_endpoints" {
  name        = "cseccon-endpoints-sg"
  description = "Allows target instance to reach SSM/Secrets Manager endpoints"
  vpc_id      = aws_vpc.main.id
  # no ingress/egress blocks here — added below as separate rules
}
# target-sg's egress -> vpc_endpoints
resource "aws_security_group_rule" "target_egress_to_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.vpc_endpoints.id
}

# vpc_endpoints' ingress <- target-sg
resource "aws_security_group_rule" "endpoints_ingress_from_target" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints.id
  source_security_group_id = aws_security_group.app_sg.id
}

# vpc_endpoints' egress (open, no cycle risk here)
resource "aws_security_group_rule" "endpoints_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port            = 0
  protocol           = "-1"
  cidr_blocks         = ["0.0.0.0/0"]
  security_group_id  = aws_security_group.vpc_endpoints.id
}