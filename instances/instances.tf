provider "aws" {
  region = var.region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
  }
  backend "s3" {
    bucket = "iac-remote-state-052023"
    key    = "layer2/infrastructure.tfstate"
    region = "ap-southeast-1"
  }
}
data "terraform_remote_state" "network_configuration" {
  backend = "s3"
  config = {
    bucket = var.remote_state_bucket
    key    = var.remote_state_key
    region = "ap-southeast-1"
  }
}

#Load Balancer Security Group
resource "aws_security_group" "elb_security_group" {
  name        = "ELB-SG"
  description = "ELB Security Group"
  vpc_id      = data.terraform_remote_state.network_configuration.outputs.vpc_id

  ingress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}
#EC2 Security Group
resource "aws_security_group" "ec2_private_security_group" {
  name        = "Ec2-public-SG"
  description = "Internet reaching access to ec2"
  vpc_id      = data.terraform_remote_state.network_configuration.outputs.vpc_id
  ingress {
    from_port   = 80
    protocol    = "TCP"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create Launch config

resource "aws_launch_configuration" "ec2_private_launch_configuration" {
  image_id                    = "ami-0126086c4e272d3c9"
  instance_type               = var.ec2_instance_type
  key_name                    = var.ec2_key_pair_name
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups             = [aws_security_group.ec2_private_security_group.id]
  lifecycle {
    create_before_destroy = true
  }
   user_data = "${file("httpd.sh")}"
  }

#IAM Role For EC2
resource "aws_iam_role" "ec2_iam_role" {
  name               = "EC2-IAM-Role"
  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement":
  [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["ec2.amazonaws.com", "application-autoscaling.amazonaws.com","ssm.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ec2_iam_role_policy" {
  name = "EC2-IAM-Policy"
  role = aws_iam_role.ec2_iam_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "cloudwatch:*",
        "logs:*",
        "ds:CreateComputer",
        "ssm:*",
        "ds:DescribeDirectories",
        "ec2:DescribeInstanceStatus",
        "ec2messages:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach AmazonSSMManagedInstanceCore policy to the IAM role
resource "aws_iam_role_policy_attachment" "ec2_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_iam_role.name
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2-IAM-Instance-Profile"
  role = aws_iam_role.ec2_iam_role.name
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "ec2_private_autoscaling_group" {
  name = "Production-Backend-AutoScalingGroup"
  vpc_zone_identifier = [
    data.terraform_remote_state.network_configuration.outputs.private-subnet-1_id,
    data.terraform_remote_state.network_configuration.outputs.private-subnet-2_id

  ]
  max_size             = var.ec2_max_instance_size
  min_size             = var.ec2_min_instance_size
  desired_capacity = 2
  launch_configuration = aws_launch_configuration.ec2_private_launch_configuration.name
  health_check_type    = "EC2"
  force_delete = true
  depends_on = [ aws_lb.ALB-tf ]
  target_group_arns = ["${aws_lb_target_group.TG-tf.arn}"]
  tag {
    propagate_at_launch = true
    key ="Backup"
    value ="True"
  }
}

# Create Target group

resource "aws_lb_target_group" "TG-tf" {
  name     = "Demo-TargetGroup-tf"
 # depends_on = [aws_vpc.main]
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.network_configuration.outputs.vpc_id
  health_check {
    interval            = 70
    path                = "/index.html"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 60 
    protocol            = "HTTP"
    matcher             = "200-499"
  }
}

# Create ALB

resource "aws_lb" "ALB-tf" {
   name              = "Demo-ALG-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.elb_security_group.id]
  subnets         = [
    data.terraform_remote_state.network_configuration.outputs.public-subnet-1_id,
    data.terraform_remote_state.network_configuration.outputs.public-subnet-2_id
    
  ]
  tags = {
	    name  = "Demo-AppLoadBalancer-tf"
    	Project = "demo-assignment"
  }
}

# Create ALB Listener 

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ALB-tf.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.TG-tf.arn
  }
}

resource "aws_cloudwatch_dashboard" "EC2_Dashboard" {
  dashboard_name = "EC2-Dashboard"
  dashboard_body = <<EOF
{
    "widgets": [
        {
            "type": "explorer",
            "width": 24,
            "height": 15,
            "x": 0,
            "y": 0,
            "properties": {
                "metrics": [
                    {
                        "metricName": "CPUUtilization",
                        "resourceType": "AWS::EC2::Instance",
                        "stat": "Maximum"
                    }
                ],
                "aggregateBy": {
                    "key": "InstanceType",
                    "func": "MAX"
                },
                "labels": [
                    {
                        "key": "State",
                        "value": "running"
                    }
                ],
                "widgetOptions": {
                    "legend": {
                        "position": "bottom"
                    },
                    "view": "timeSeries",
                    "rowsPerPage": 8,
                    "widgetsPerRow": 2
                },
                "period": 60,
                "title": "Running EC2 Instances CPUUtilization"
            }
        }
    ]
}
EOF
}

#Create AWS Backup
resource "aws_backup_vault" "onebackup" {
  name        = "onebackup_backup_vault"
}

resource "aws_backup_plan" "onebackup" {
  name = "tf_eonebackup_backup_plan"
  rule {
    rule_name         = "tf_onebackup_backup_rule"
    target_vault_name = aws_backup_vault.onebackup.name
    schedule          = "cron(0 12 * * ? *)"
    lifecycle {
      delete_after = 7 
    }
  }
}

resource "aws_iam_role" "default" {
  name               = "DefaultBackupRole"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "onebackup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.default.name
}

resource "aws_backup_selection" "onebackup" {
  iam_role_arn = aws_iam_role.default.arn
  name         = "tf_onebackup_backup_selection"
  plan_id      = aws_backup_plan.onebackup.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "backup"
    value = "True"
  }
}