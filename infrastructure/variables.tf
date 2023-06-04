variable "region" {
    default      = "ap-southeast-1"
    description  = "AWS Region"
}

variable "vpc_cidr" {
       description = "VPC CIDR Block"
 
}

variable "public_subnet_1_cidr" {
  description = "CIDR BLOCK FOR public subnet 1"
}

variable "public_subnet_2_cidr" {
  description = "CIDR BLOCK FOR public subnet 2"
}

variable "private_subnet_1_cidr" {
  description = "CIDR BLOCK FOR private subnet 1"
}

variable "private_subnet_2_cidr" {
  description = "CIDR BLOCK FOR private subnet 2"
}


variable "private_subnet_3_cidr" {
  description = "CIDR BLOCK FOR private subnet 1"
}

variable "private_subnet_4_cidr" {
  description = "CIDR BLOCK FOR private subnet 2"
}
