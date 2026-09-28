resource "aws_ecr_repository" "repo" {
  name                 = "${var.challenge_name}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Purpose = "${var.challenge_name}ECR-repo"
  }
}

resource "aws_ecr_lifecycle_policy" "ecr-policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
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
resource "aws_cloudwatch_log_group" "exec_logs" {
  name              = "/${var.challenge_name}/ecs-exec"
  retention_in_days = 7
}