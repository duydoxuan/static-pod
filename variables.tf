# variables.tf
variable "vpc_id" {
  description = "The VPC ID where resources will be created."
  type        = string
}

variable "ami" {
  description = "The AMI ID for the instance."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type."
  type        = string
}

variable "public_key" {
  description = "The public SSH key content."
  type        = string
}

variable "private_key" {
  description = "Path to the private key file for SSH."
  type        = string
}