# Pin the version of Terraform
terraform {
  required_version = "0.12.23"
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws-region
}

# Look up the IAM roles and profiles pre-defined by AWS
data "aws_iam_role" "iam_emr_service_role" {
  name = "EMR_DefaultRole"
}

data "aws_iam_role" "iam_emr_autoscaling_role" {
  name = "EMR_AutoScaling_DefaultRole"
}

data "aws_iam_instance_profile" "emr_profile" {
  name = "EMR_EC2_DefaultRole"
}

resource "aws_security_group" "bastion_accessable" {
  name = "Bastion-accessible"
  description = "Allow access to EMR instances via the bastion a a jumpbox"

  vpc_id = var.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    // TODO pull from bastion creation definition
    security_groups = [
      "sg-06d885349b809c615"
    ]
  }
}

# Create the cluter if it doesn't already exist
# See: https://www.terraform.io/docs/providers/aws/r/emr_cluster.html
resource "aws_emr_cluster" "this" {
  name          = "interactive-cluster"
  release_label = "emr-5.29.0"
  applications  = [
    "Ganglia",
    "Spark",
    "Zeppelin",
  ]

  termination_protection = false
  keep_job_flow_alive_when_no_steps = true

  service_role = data.aws_iam_role.iam_emr_service_role.arn
  autoscaling_role = data.aws_iam_role.iam_emr_autoscaling_role.arn

  ec2_attributes {
    subnet_id        = var.emr-subnet-id
    instance_profile = data.aws_iam_instance_profile.emr_profile.arn
    key_name         = var.key-name

    additional_master_security_groups = aws_security_group.bastion_accessable.id
    additional_slave_security_groups = aws_security_group.bastion_accessable.id
  }

  master_instance_group {
    instance_type = "m5.xlarge"

    bid_price = "0.20"
  }

  core_instance_group {
    instance_type  = "r5.xlarge"
    instance_count = 2

    ebs_config {
      size                 = "40"
      type                 = "gp2"
      volumes_per_instance = 1
    }

    bid_price = "0.30"

    autoscaling_policy = <<EOF
{
  "Constraints": {
    "MinCapacity": 1,
    "MaxCapacity": 10
  },
  "Rules": [
    {
      "Name": "ScaleOut-MemoryPercentage",
      "Description": "Scale out if YARNMemoryAvailablePercentage is less than 15",
      "Action": {
        "SimpleScalingPolicyConfiguration": {
          "AdjustmentType": "CHANGE_IN_CAPACITY",
          "ScalingAdjustment": 5,
          "CoolDown": 300
        }
      },
      "Trigger": {
        "CloudWatchAlarmDefinition": {
          "ComparisonOperator": "LESS_THAN",
          "EvaluationPeriods": 1,
          "MetricName": "YARNMemoryAvailablePercentage",
          "Namespace": "AWS/ElasticMapReduce",
          "Period": 300,
          "Statistic": "AVERAGE",
          "Threshold": 15.0,
          "Unit": "PERCENT"
        }
      }
    },
    {
      "Name": "ScaleOut-PendingContainersRatio",
      "Description": "Scale out if 75% of the task containers are still pending",
      "Action": {
        "SimpleScalingPolicyConfiguration": {
          "AdjustmentType": "CHANGE_IN_CAPACITY",
          "ScalingAdjustment": 5,
          "CoolDown": 300
        }
      },
      "Trigger": {
        "CloudWatchAlarmDefinition": {
          "ComparisonOperator": "GREATER_THAN",
          "EvaluationPeriods": 1,
          "MetricName": "ContainerPendingRatio",
          "Namespace": "AWS/ElasticMapReduce",
          "Period": 300,
          "Statistic": "AVERAGE",
          "Threshold": 0.75,
          "Unit": "NONE"
        }
      }
    },

    {
      "Name": "ScaleIn-MemoryPercentage",
      "Description": "Scale in if YARNMemoryAvailablePercentage is greater than 75",
      "Action": {
        "SimpleScalingPolicyConfiguration": {
          "AdjustmentType": "CHANGE_IN_CAPACITY",
          "ScalingAdjustment": 1,
          "CoolDown": 300
        }
      },
      "Trigger": {
        "CloudWatchAlarmDefinition": {
          "ComparisonOperator": "GREATER_THAN",
          "EvaluationPeriods": 1,
          "MetricName": "YARNMemoryAvailablePercentage",
          "Namespace": "AWS/ElasticMapReduce",
          "Period": 300,
          "Statistic": "AVERAGE",
          "Threshold": 75.0,
          "Unit": "PERCENT"
        }
      }
    },
    {
      "Name": "ScaleIn-IdleCluster",
      "Description": "Scale in if the cluter is not being used",
      "Action": {
        "SimpleScalingPolicyConfiguration": {
          "AdjustmentType": "CHANGE_IN_CAPACITY",
          "ScalingAdjustment": 10,
          "CoolDown": 300
        }
      },
      "Trigger": {
        "CloudWatchAlarmDefinition": {
          "ComparisonOperator": "GREATER_THAN_OR_EQUAL",
          "EvaluationPeriods": 3,
          "MetricName": "IsIdle",
          "Namespace": "AWS/ElasticMapReduce",
          "Period": 300,
          "Statistic": "AVERAGE",
          "Threshold": 1,
          "Unit": "NONE"
        }
      }
    }
  ]
}
EOF
  }
}
