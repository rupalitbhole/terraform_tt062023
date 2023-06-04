provider "aws" {
  region = var.region
}

terraform {
    required_providers {
      aws ={
        source = "hashicorp/aws"
        version = "~> 4.0"
      }
    }
    #backend S3 
  backend "s3" {
    bucket = "iac-remote-state-052023"
    key = "layer1/infrastructure.tfstate"
    } 
}
#vpc creation
resource "aws_vpc" "production-vpc" {
    cidr_block        = var.vpc_cidr
    enable_dns_hostnames   = true
    tags   = {
      Name ="Production-VPC"
    }
  
}

#Subnet Creation
resource "aws_subnet" "public-subnet-1" {
    cidr_block        = var.public_subnet_1_cidr
    vpc_id            = aws_vpc.production-vpc.id
    availability_zone = "${var.region}a"
    tags = {
    Name = "Public-subnet-web-1"
    }
  
}

resource "aws_subnet" "public-subnet-2" {
    cidr_block = var.public_subnet_2_cidr
    vpc_id = aws_vpc.production-vpc.id
    availability_zone = "${var.region}b"
    tags = {
    Name = "Public-subnet-web-2"
    }
  
}

resource "aws_subnet" "private-subnet-1" {
    cidr_block = var.private_subnet_1_cidr
    vpc_id = aws_vpc.production-vpc.id
    availability_zone = "${var.region}a"
    tags = {
    Name = "Private-subnet-app-1"
    }
  
}

resource "aws_subnet" "private-subnet-2" {
    cidr_block = var.private_subnet_2_cidr
    vpc_id = aws_vpc.production-vpc.id
    availability_zone = "${var.region}b"
    tags = {
    Name = "Private-subnet-app-2"
    }
}

resource "aws_subnet" "private-subnet-3" {
    cidr_block = var.private_subnet_3_cidr
    vpc_id = aws_vpc.production-vpc.id
    availability_zone = "${var.region}a"
    tags = {
    Name = "Private-subnet-db-1"
    }
  
}

resource "aws_subnet" "private-subnet-4" {
    cidr_block = var.private_subnet_4_cidr
    vpc_id = aws_vpc.production-vpc.id
    availability_zone = "${var.region}b"
    tags = {
    Name = "Private-subnet-db-2"
    }
  
}

#Route Table Creation

resource "aws_route_table" "public-route-table" {

    vpc_id = aws_vpc.production-vpc.id
    tags = {
      Name = "Public-Route-Table"
    }
}

resource "aws_route_table" "private-route-table" {
    vpc_id = aws_vpc.production-vpc.id
    tags = {
      Name="Private-Route-Table"
    }
}

#Route table association with respective Subnet
resource "aws_route_table_association" "public-route-1-association" {
    route_table_id = aws_route_table.public-route-table.id
    subnet_id = aws_subnet.public-subnet-1.id 
}
resource "aws_route_table_association" "public-route-2-association" {
    route_table_id = aws_route_table.public-route-table.id
    subnet_id = aws_subnet.public-subnet-2.id
}
resource "aws_route_table_association" "private-route-1-association" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id = aws_subnet.private-subnet-1.id
}
resource "aws_route_table_association" "private-route-2-association" {
    route_table_id = aws_route_table.private-route-table.id
    subnet_id = aws_subnet.private-subnet-2.id
}

#creation of internet gateway and route table
resource "aws_internet_gateway" "production-igw" {
  vpc_id = aws_vpc.production-vpc.id
  tags = {
    Nmae="Production-IGW"
  }
}
resource "aws_route" "public-internet-igw-route" {
    route_table_id = aws_route_table.public-route-table.id
    gateway_id = aws_internet_gateway.production-igw.id
    destination_cidr_block = "0.0.0.0/0"
  
}


#creation of elastic IP and NAT gateway
resource "aws_eip" "elastic-ip-for-nat-gateway" {
  vpc =true
  associate_with_private_ip = "10.0.0.5"
  tags = {
    Name="Production-EIP"
  }
  depends_on = [aws_internet_gateway.production-igw]
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.elastic-ip-for-nat-gateway.id
  subnet_id = aws_subnet.public-subnet-1.id
  tags = {
    Name= "Production-NAT-GW"
  }
  depends_on = [ aws_eip.elastic-ip-for-nat-gateway ]
}

resource "aws_route" "nat-gw-route" {
  route_table_id = aws_route_table.private-route-table.id
  gateway_id = aws_nat_gateway.nat-gw.id
  destination_cidr_block = "0.0.0.0/0"
}