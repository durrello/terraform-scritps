# Terraform script to create and launch ec2 webserver instance

provider "aws" {
  region     = "us-east-1"
  access_key = "access_key"
  secret_key = "secret_key"
}

# Create key pair

# Create VPC
resource "aws_vpc" "webserver-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create internet gateway
resource "aws_internet_gateway" "webserver-igw" {
  vpc_id = aws_vpc.webserver-vpc.id

  tags = {
    Name = "webserver-igw"
  }
}

# Custom route table
resource "aws_route_table" "webserver-rtb" {
  vpc_id = aws_vpc.webserver-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webserver-igw.id
  }

  tags = {
    Name = "example"
  }
}

# Create subnet
resource "aws_subnet" "webserver-sb" {
  vpc_id     = aws_vpc.webserver-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "webserver-sb"
  }
}

# Associate subnet with route table
resource "aws_route_table_association" "webserver-sb-a" {
  subnet_id      = aws_subnet.webserver-sb.id
  route_table_id = aws_route_table.webserver-rtb.id
}

# Create security group
resource "aws_security_group" "allow_web" {
  name        = "allow_webtraffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.webserver-vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_webserver"
  }
}

# Create network interface 
resource "aws_network_interface" "webserver-nic" {
  subnet_id       = aws_subnet.webserver-sb.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# Create public elastic ip
resource "aws_eip" "webserver-elip" {
  vpc                       = true
  network_interface         = aws_network_interface.webserver-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.webserver-igw]
}

# Create instance
resource "aws_instance" "webserver-instance" {
  ami           = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "terraform-dev"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.webserver-nic.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    EOF

  tags = {
    Name = "Webserver"
  }
}