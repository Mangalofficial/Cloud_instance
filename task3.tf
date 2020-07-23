provider "aws" {
  region = "ap-south-1"
  profile = "manglam"
}

resource "aws_vpc" "vpc-1" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "myvpc" 
  }
}

resource "aws_subnet" "private" {
  depends_on = [ aws_vpc.vpc-1 ]
  vpc_id = aws_vpc.vpc-1.id
  cidr_block = "192.168.10.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "subnet-1a"
  }
}

resource "aws_subnet" "public" {
  depends_on = [ aws_vpc.vpc-1 ]
  vpc_id = aws_vpc.vpc-1.id
  cidr_block = "192.168.20.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "subnet-1b"
  }
}

resource "aws_internet_gateway" "Door" {
  depends_on = [ aws_vpc.vpc-1 ]
  vpc_id = aws_vpc.vpc-1.id
  tags = {
    Name = "mygateway"
  }
}

resource "aws_route_table" "table" {
  depends_on = [aws_vpc.vpc-1, aws_internet_gateway.Door]
  vpc_id = aws_vpc.vpc-1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Door.id
  }
  tags = {
    Name = "route-table"
  }
}

resource "aws_route_table_association" "private-tabel" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.table.id
}

resource "aws_route_table_association" "public-tabel" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.table.id
}

resource "aws_security_group" "my_security1" {
  name        = "my_security1"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.vpc-1.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security"
  }
}

resource "aws_instance" "wordpress" {
  ami = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.my_security1.id]
  key_name = "AWS-key"
  subnet_id = aws_subnet.public.id
  tags = {
    Name = "Wordpress"
  }
}

resource "aws_instance" "Mysql" {
  ami = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.my_security1.id]
  key_name = "AWS-key"
  subnet_id = aws_subnet.private.id
  tags = {
    Name = "MySQL"
  }
}

