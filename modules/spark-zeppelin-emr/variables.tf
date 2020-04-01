variable "aws-region" {
  description = "AWS region in which the resources will be created"
  type = string
}

variable "vpc_id" {
  description = "VPC in which the EMR cluster will be created"
  type = string
}

variable "emr-subnet-id" {
  description = "Subnet in which the EMR cluster will be created"
  type = string
}

variable "bastion-security-group" {
  description = "Security group ID of the bastion that gatekeeps access to the cluster"
  type = string
}

variable "key-name" {
  description = "The nmae of the key-pair to use to connect to the EMR isntances"
  type = string
}