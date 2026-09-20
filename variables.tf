variable "region" {
  description = "Region hosting the public-facing vulnerable app server"
  type        = string
  default     = "us-east-1"
}
variable "challenge_name" {
    description = "Name of the challenge"
    type = string
    default = "Clusterduck"
}
variable "vpc_cidr_block" {
    description = "VPC CIDR Block"
    default = "10.0.0.0/16"
}
variable "flag_value" {
    description = "Flag value for the challenge"
    type = string
    sensitive = true
}