resource "aws_secretsmanager_secret" "flag" {
  name                    = "${var.challenge_name}/flag"
  description             = "CTF flag - readable only by the flag task's execution role"
  recovery_window_in_days = 0

  tags = {
    Purpose = "${var.challenge_name}-flag"
  }
}

resource "aws_secretsmanager_secret_version" "flag" {
  secret_id     = aws_secretsmanager_secret.flag.id
  secret_string = var.flag_value
}