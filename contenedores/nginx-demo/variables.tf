#ingresar credenciales
variable "access_key" {}
variable "secret_key" {}
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "us-east-1"
}

variable "ecs_cluster" {
  type        = "string"
  description = "indicar el nombre del cluster"
}

