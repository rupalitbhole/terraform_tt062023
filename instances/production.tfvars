remote_state_bucket = "iac-remote-state-052023"
remote_state_key    = "layer1/infrastructure.tfstate"
region              = "ap-southeast-1"


# EC2 variables for production
ec2_instance_type     = "t2.micro"
ec2_min_instance_size = 2
ec2_max_instance_size = 6


