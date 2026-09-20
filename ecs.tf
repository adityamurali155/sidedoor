data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
}

locals {
  ecs_ami_id = jsondecode(data.aws_ssm_parameter.ecs_ami.value)["image_id"]
}
resource "aws_key_pair" "app_admin" {
  key_name   = "cseccon-app-admin-key"
  public_key = file("~/.ssh/cseccon-app-key.pub")
}
resource "aws_instance" "ecs_node" {
  ami                    = local.ecs_ami_id
  instance_type          = "t3.small"
  key_name               = aws_key_pair.app_admin.key_name
  iam_instance_profile   = aws_iam_instance_profile.ecs_instance_profile.name
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # No public IP — same reasoning as your original app-server decision
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF

  metadata_options {
    http_tokens = "optional"  # deliberately NOT "required" — this is what keeps IMDSv1 usable for the SSRF
  }
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.challenge_name}-app"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge" # required for the host-IMDS SSRF path
  execution_role_arn       = aws_iam_role.app_execution_role.arn
  # deliberately no task_role_arn — see note below

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 80
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

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.app_listener]
}
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.challenge_name}-app"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "flag_task" {
  family                   = "${var.challenge_name}-flag-holder"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.flag_task_execution_role.arn
  task_role_arn            = aws_iam_role.flag_task_role.arn

  container_definitions = jsonencode([{
    name              = "flag-holder"
    image             = "public.ecr.aws/docker/library/alpine:latest"
    command           = ["sh", "-c", "sleep infinity"]
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