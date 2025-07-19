variable "region" {
  type    = string
  default = "us-west-2"
}

variable "my_instance" {
  type    = string
  default = "t2.micro"
}

variable "my_key" {
  type    = string
  default = "maxo"
}


variable "instance_user" {
  default = "ubuntu"
}