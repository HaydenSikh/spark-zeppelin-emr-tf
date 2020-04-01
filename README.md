# Spark and Zeppelin on AWS EMR

**Note** At the current time this is intended as instructive and still some
rough patches to work out.  Use at your own risk.

This is a composition of three modules:

  - `terraform-aws-modules/vpc/aws` for creating a VPC with a fully private subnet
  - `jetbrains-infra/terraform-aws-bastion-host` for creating a jumpbox into 
     the private subnets
  - the module defined here
  
 If you already have a VPC and jumpbox set up then you should just use the
 `modules/spark-zeppelin-emr` module rather than using the `main.tf`.

## Prerequisites

This module requires Terraform version 0.12.23.  

The usage of a package manager may be advisable to enable you to use different
versions of Terraform for other purposes, but this is not required.  For those 
interested in using a package manager then [asdf](https://github.com/asdf-vm/asdf)
has worked well for the author in the past.

##  Manual configuration

- The 3rd-party module for creating the bastion does not export much 
  information about the instance.  Since the EMR cluster is configured to only 
  allow access via an SSH tunnel from the bastion, it needs to have the security
  group of the bastion manually passed in.  This means that currently the 
  workflow is:
    - comment out the `spark-zeppelin-emr` module in main
    - terrafom apply
    - uncomment the `spark-zeppelin-emr` module
    - update the `bastion-security-group` appropriately
    - terraform apply
- The default IAM roles and instance profiles used by EMR might not be created 
  until a cluster has been created manually.  If you get an error then it's 
  probably best to use the wizard in AWS console to create those before using 
  this script.
  
## Execution
 
 ```shell script
TF_VAR_key_name="<some key in ec2>" \
  terraform apply
```
  
## SSH configuration

To access the EMR cluster over SSH -- which is required to tunnel to the UIs 
hosted on EMR such as Zeppelin -- then a configuration like the following will 
work:

```
Host bastion
  HostName <public IP or host name of bastion>
  User centos
  IdentityFile ~/path/to/private_key.pem
  ForwardAgent yes

Host emr-master
  HostName <private IP of the EMR master node>
  User hadoop
  ProxyJump bastion
  IdentityFile ~/path/to/private_key.pem
```

The `bastion` and `emr-master` Host values are arbitrary aliases and can be 
changed as you see fit so long as the `ProxyJump` reference is also updated.

This configuration will enable SSHing into the EMR master with just:
```shell script
ssh emr-master
```

This handles:

  - logging into the bastion with the correct user name and key
  - instructing the bastion to forward the SSH agent
  - jumping to the emr-master node with the correct user name and key