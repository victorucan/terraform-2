resource "aws_vpc" "pri_vpc" {
  cidr_block           = "10.0.0.0/8"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "subpub1" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.252.0.0/16"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub1"
  }
}

resource "aws_subnet" "subpub2" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.253.0.0/16"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub2"
  }
}

resource "aws_subnet" "subpriv1" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.254.0.0/16"
  map_public_ip_on_launch = false

  tags = {
    Name = "priv1"
  }
}

resource "aws_subnet" "subpriv2" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.255.0.0/16"
  map_public_ip_on_launch = false

  tags = {
    Name = "priv2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.pri_vpc.id

  tags = {
    Name = "gw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.pri_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "route_table"
  }
}

resource "aws_route_table_association" "as1" {
  subnet_id      = aws_subnet.subpriv1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "as2" {
  subnet_id      = aws_subnet.subpriv2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "dev_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.pri_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "key" {
  key_name   = "mykey"
  public_key = file("/home/ubuntu/.ssh/mykey.pub")
}

resource "aws_instance" "web1" {
  instance_type = "t2.micro"
  ami           = "ami-0ff39345bd62c82a5"
  key_name = aws_key_pair.key.id
  subnet_id = aws_subnet.subpriv1.id
  user_data = file("userdata.tpl")
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  tags = {
    Name = "nginx1"
  }
  
  root_block_device {
    volume_size= 10
  }
}
resource "aws_instance" "web2" {
  instance_type = "t2.micro"
  ami           = "ami-0ff39345bd62c82a5"
  key_name = aws_key_pair.key.id
  subnet_id = aws_subnet.subpriv2.id
  user_data = file("userdata.tpl")
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  tags = {
    Name = "nginx2"
  }
  
  root_block_device {
    volume_size= 10
  }
}