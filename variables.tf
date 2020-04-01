variable "aws_region" {
  description = "AWS region in which the resources will be created"
  type = string
  default = "us-west-1"
}

variable "key_name" {
  description = "The nmae of the key-pair to use to connect to the EMR isntances"
  type = string
}

variable "trusted_cidrs" {
  description = "List of CIDRs which are trusted to access the bastion"
  type = list(string)
  default = [
    "98.207.137.180/32"
  ]
}