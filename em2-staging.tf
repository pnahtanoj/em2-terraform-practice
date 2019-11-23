##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
  default = "us-west-2"
}
variable "network_address_space" {
  default = "10.1.0.0/16"
}
variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}


##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "em2_staging_vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"

}

resource "aws_internet_gateway" "em2_staging_igw" {
  vpc_id = aws_vpc.em2_staging_vpc.id

}

resource "aws_subnet" "em2_staging_subnet1" {
  cidr_block              = var.subnet1_address_space
  vpc_id                  = aws_vpc.em2_staging_vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]

}

# ROUTING #
resource "aws_route_table" "em2_staging_rtb" {
  vpc_id = aws_vpc.em2_staging_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.em2_staging_igw.id
  }
}

resource "aws_route_table_association" "em2_staging_rta-subnet1" {
  subnet_id      = aws_subnet.em2_staging_subnet1.id
  route_table_id = aws_route_table.em2_staging_rtb.id
}

# SECURITY GROUPS #
resource "aws_security_group" "em2_staging_sg" {
  name        = "em2-staging"
  description = "SG for EM2 Staging"
  vpc_id      = aws_vpc.em2_staging_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INSTANCES #
resource "aws_instance" "em2_staging_instance" {
  ami                    = data.aws_ami.aws-linux.id
  tags                   = {
    name  = "EM2 Staging Instance"
  }
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.em2_staging_subnet1.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.em2_staging_sg.id]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start"
    ]
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_instance_public_dns" {
  value = aws_instance.em2_staging_instance.public_dns
}
