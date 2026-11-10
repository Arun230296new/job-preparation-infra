variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type    = string
  default = "job-preparation"
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.0.0/20", "10.40.16.0/20"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.128.0/20", "10.40.144.0/20"]
}
