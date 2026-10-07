data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
}

locals {
  ecs_ami_id = jsondecode(data.aws_ssm_parameter.ecs_ami.value)["image_id"]
}
resource "aws_instance" "ecs_node" {
  ami                    = local.ecs_ami_id
  instance_type          = "t3.small"
  iam_instance_profile   = aws_iam_instance_profile.ecs_instance_profile.name
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  availability_zone       = "${var.region}a"

  # No public IP — same reasoning as your original app-server decision
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF

  metadata_options {
    http_tokens = "optional"  # deliberately NOT "required" — this is what keeps IMDSv1 usable for the SSRF
  }
  tags = {
    Name    = "${var.challenge_name}-ecs-node"
    Purpose = "ECS cluster node for challenge"
  }
}
resource "aws_ecs_cluster" "main" {
  name = "${var.challenge_name}-cluster"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.exec_logs.name
      }
    }
  }

  tags = {
    Purpose = "ECS-cluster-hosting"
  }
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.challenge_name}-app"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge" # required for the host-IMDS SSRF path
  execution_role_arn       = aws_iam_role.app_execution_role.arn
  # deliberately no task_role_arn — see note below

  container_definitions = jsonencode([{
    name      = "payroll-app"
    image     = "${aws_ecr_repository.repo.repository_url}:latest"
    essential = true
    memoryReservation = 512

    portMappings = [{
      containerPort = 8000
      hostPort      = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

resource "aws_ecs_service" "app_service" {
  name            = "${var.challenge_name}-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "EC2"

  # only one instance, only one hostPort — a rolling deploy trying
  # to run 2 tasks at once would just fail to place the second one
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  health_check_grace_period_seconds = 120

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "payroll-app"
    container_port   = 8000
  }
  depends_on = [aws_lb_listener.app_listener]
}

resource "aws_ecs_task_definition" "flag_task" {
  family                   = "${var.challenge_name}-flag-holder"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.flag_task_execution_role.arn
  task_role_arn            = aws_iam_role.flag_task_role.arn

  container_definitions = jsonencode([{
    name              = "flag-holder"
    image             = "${aws_ecr_repository.repo.repository_url}:flag-base"
    essential         = true
    memoryReservation = 64

    secrets = [{
      name      = "FLAG"
      valueFrom = aws_secretsmanager_secret.flag.arn
    }]
  }])
}

resource "aws_ecs_service" "flag_service" {
  name                   = "${var.challenge_name}-flag-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.flag_task.arn
  desired_count          = 1
  launch_type            = "EC2"
  enable_execute_command = true # easy to miss — without this, ExecuteCommand fails even with correct IAM

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.challenge_name}-app"
  retention_in_days = 7
}
resource "aws_cloudwatch_log_group" "exec_logs" {
  name              = "/${var.challenge_name}/ecs-exec"
  retention_in_days = 7
}