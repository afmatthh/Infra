variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_securitygroupid" {
  type = "list"
}
variable "aws_keyname" {}
variable "private_key_file" {}
variable "region" {
  default = "eu-central-1"
}
variable "amis" {
  type = "map"
  default = {
    "eu-central-1" = "ami-c7ee5ca8"
  }
}
variable "size" {
  type = "map"
  default = {
    "teamcity" = "t2.medium"
    "web"      = "t2.small"
  }
}