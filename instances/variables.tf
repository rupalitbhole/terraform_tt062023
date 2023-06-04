variable "region" {
  default     = "ap-southeast-1"
  description = "AWS Region"
}

variable "remote_state_bucket" {
  description = "bucket name for layer1 remote state"
}

variable "remote_state_key" {
  description = "key name for layer1 remote state"
}

variable "ec2_instance_type" {
  description = "Ec2 instance type to launch"
}

variable "ec2_key_pair_name" {
  default     = "myEc2Keypair"
  description = "Keypair to use to connect to ec2 instances"
}

variable "ec2_min_instance_size" {
  description = "Minimum number of instances to launch in AutoScaling Group"
}

variable "ec2_max_instance_size" {
  description = "Maximum number of instances to launch in AutoScaling Group"
}

variable "tag_production" {
  default = "Production"
}

variable "tag_webapp" {
  default = "WebApp"
}

variable "tag_backend" {
  default = "Backend"
}

