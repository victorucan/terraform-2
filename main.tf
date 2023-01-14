resource "aws_vpc" "pri_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "subpub1" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2a"

  tags = {
    Name = "pub1"
  }
}

resource "aws_subnet" "subpub2" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2b"

  tags = {
    Name = "pub2"
  }
}

resource "aws_subnet" "subpriv1" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.1.3.0/24"
  map_public_ip_on_launch = false
  availability_zone = "us-east-2a"

  tags = {
    Name = "priv1"
  }
}

resource "aws_subnet" "subpriv2" {
  vpc_id     = aws_vpc.pri_vpc.id
  cidr_block = "10.1.4.0/24"
  map_public_ip_on_launch = false
  availability_zone = "us-east-2b"

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

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subpub1.id

  tags = {
    Name = "NAT"
  }

 depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "rt1" {
  vpc_id = aws_vpc.pri_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "rt_Public"
  }
}

resource "aws_route_table" "rt2" {
  vpc_id = aws_vpc.pri_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "rt_Priv"
  }
}

resource "aws_route_table_association" "as1" {
  subnet_id      = aws_subnet.subpriv1.id
  route_table_id = aws_route_table.rt1.id
}

resource "aws_route_table_association" "as2" {
  subnet_id      = aws_subnet.subpriv2.id
  route_table_id = aws_route_table.rt1.id
}

resource "aws_route_table_association" "as3" {
  subnet_id      = aws_subnet.subpub1.id
  route_table_id = aws_route_table.rt2.id
}

resource "aws_route_table_association" "as4" {
  subnet_id      = aws_subnet.subpub2.id
  route_table_id = aws_route_table.rt2.id
}

resource "aws_security_group" "dev_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.pri_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]
  }
}

resource "aws_security_group" "alb" {
  name        = "alb"
  description = "alb network traffic"
  vpc_id      = aws_vpc.pri_vpc.id

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.dev_sg.id]
  }

  tags = {
    Name = "allow traffic"
  }
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = file("${var.pub_key}")
}

data "aws_ami" "Nginx" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # jammy
}

resource "aws_launch_template" "launchtemplate1" {
  name = "web"

  image_id               = data.aws_ami.Nginx.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.mykey.id
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "WebServer"
    }
  }

  user_data = filebase64("${path.module}/ec2.userdata")
}


resource "aws_lb" "LB" {
  name               = "Terraform-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.subpriv1.id, aws_subnet.subpriv2.id]

  enable_deletion_protection = false
}
  /*

  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    prefix  = "test-lb"
    enabled = true
  }

  tags = {
    Environment = "production"
  }
}
*/

resource "aws_alb_target_group" "webserver" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.pri_vpc.id
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_lb.LB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }
}

resource "aws_alb_listener_rule" "rule1" {
  listener_arn = aws_alb_listener.front_end.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [aws_subnet.subpriv1.id, aws_subnet.subpriv2.id]

  desired_capacity = 2
  max_size         = 3
  min_size         = 2

  target_group_arns = [aws_alb_target_group.webserver.arn]

  launch_template {
    id      = aws_launch_template.launchtemplate1.id
    version = "$Latest"
  }
}



