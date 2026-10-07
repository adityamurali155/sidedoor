resource "aws_iam_role" "ecs_instance_role" {
  name = "staffsync-app-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
resource "aws_iam_role_policy" "self_enumeration" {
  name = "self-enumeration"
  role = aws_iam_role.ecs_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "iam:GetRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies"
        # deliberately no iam:GetRolePolicy — see below
      ]
      Resource = aws_iam_role.ecs_instance_role.arn
    }]
  })
}
# Baseline permissions the ECS agent itself needs to register with the cluster, pull images, report status, etc.
resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# The intentionally-scoped privesc path: this role can ExecuteCommand only into the specific privileged task/cluster that holds the flag.
resource "aws_iam_role_policy" "pivot_to_privileged_task" {
  name = "ecs-exec-scoped-policy"
  role = aws_iam_role.ecs_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:ListClusters", "ecs:DescribeClusters"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:ListTasks", "ecs:DescribeTasks", "ecs:DescribeTaskDefinition"]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "ecs:ExecuteCommand"
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
          StringEquals = {
            "ecs:container-name" = "flag-holder"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "ssm:StartSession"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-container-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "app_execution_role" {
  name = "${var.challenge_name}-app-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_execution_base" {
  role       = aws_iam_role.app_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "flag_task_execution_role" {
  name = "secret-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "flag_execution_base" {
  role       = aws_iam_role.flag_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "flag_execution_secret_read" {
  name = "read-flag-secret"
  role = aws_iam_role.flag_task_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.flag.arn
    }]
  })
}

resource "aws_iam_role" "flag_task_role" {
  name = "flag-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flag_task_exec_session" {
  name = "allow-ecs-exec-session"
  role = aws_iam_role.flag_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}
resource "aws_iam_role_policy" "flag_task_exec_logging" {
  name = "${var.challenge_name}-flag-task-exec-logging"
  role = aws_iam_role.flag_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.exec_logs.arn}:*"
      }
    ]
  })
}