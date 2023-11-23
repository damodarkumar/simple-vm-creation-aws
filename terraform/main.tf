#Providers

provider "aws" {
  region  = var.provider_region
}

#Create VPC

resource "aws_vpc" "pe_custom_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "pe Custom VPC"
  }
}


#Create subnets for different parts of the infrastructure

resource "aws_subnet" "pe_public_subnet" {
  vpc_id            = aws_vpc.pe_custom_vpc.id
  cidr_block        = "10.0.1.0/24"
# availability_zone = "1a"

  tags = {
    Name = "pe Public Subnet"
  }
}

resource "aws_subnet" "pe_private_subnet" {
  vpc_id            = aws_vpc.pe_custom_vpc.id
  cidr_block        = "10.0.2.0/24"
# availability_zone = "1a"

  tags = {
    Name = "pe Private Subnet"
  }
}

#Attach an internet gateway to the VPC
resource "aws_internet_gateway" "pe_ig" {
  vpc_id = aws_vpc.pe_custom_vpc.id

  tags = {
    Name = "pe Internet Gateway"
  }
}


# Create a route table for a public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.pe_custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pe_ig.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.pe_ig.id
 }

  tags = {
    Name = "Public Route Table"
  }
}

#Resource: aws_route_table_association
resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.pe_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#Create security groups to allow specific traffic
resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH"
  vpc_id = aws_vpc.pe_custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

# use ubuntu 20 AMI for EC2 instance
data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/*20.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
    
    owners = ["099720109477"] # Canonical
}

#Resource: aws_instance
resource "aws_instance" "web_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_type
  key_name      = "githubworkflow-ec2-key"

  subnet_id                   = aws_subnet.pe_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
  #!/bin/bash -ex

  amazon-linux-extras install nginx1 -y
  echo "<h1>$(curl https://api.kanye.rest/?format=text)</h1>" >  /usr/share/nginx/html/index.html 
  systemctl enable nginx
  systemctl start nginx
  EOF

  tags = {
    Name = var.ec2_name
    instance_type = var.ec2_type
    region = var.provider_region
  }
}
