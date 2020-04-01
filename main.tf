# Pin the version of Terraform
terraform {
 required_version = "0.12.23"
}

# Configure the AWS Provider
provider "aws" {
  version = "~> 2.52"
  region = var.aws_region
}

locals {
  network_prefix = "10.0"
  az_config = [
    {
      name: "${var.aws_region}a",
      public_cidr: "${local.network_prefix}.101.0/24",
      private_cidr: "${local.network_prefix}.1.0/24",
    }
  ]
}

// Use a pre-defined module to bootstrap into a well-defined VPC network
// For long-term or production use then this would be good to define in-house
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "2.25.0"

  name = "main"
  cidr = "10.0.0.0/16"

  // An EMR cluster runs in a single AZ, so for this minimal example just
  // set up a single AZ
  azs = [
    local.az_config[0].name
  ]
  private_subnets = [
    local.az_config[0].private_cidr
  ]
  public_subnets  = [
    local.az_config[0].public_cidr
  ]

  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true
  enable_vpn_gateway = false

  // Disable the infrastructure we're not going to use
  create_database_subnet_group = false
  create_database_subnet_route_table = false

  create_elasticache_subnet_group = false
  create_elasticache_subnet_route_table = false

  create_redshift_subnet_group = false
  create_redshift_subnet_route_table = false
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  auto_accept = true
  route_table_ids = module.vpc.private_route_table_ids
}

module "bastion" {
  source            = "github.com/jetbrains-infra/terraform-aws-bastion-host"
  subnet_id         = module.vpc.public_subnets[0]
  ssh_key           = var.key_name
  internal_networks = [ local.az_config[0].private_cidr ]
  project           = "emr-cluster"

  allowed_hosts     = var.trusted_cidrs
}

module "zeppelin-emr" {
  source = "./modules/spark-zeppelin-emr"

  aws-region = var.aws_region
  vpc_id = module.vpc.vpc_id
  emr-subnet-id = module.vpc.private_subnets[0]
  bastion-security-group = "sg-06d885349b809c615" // TODO export from bastion
  key-name = var.key_name
}
