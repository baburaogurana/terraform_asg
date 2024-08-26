provider "aws" {
  region = "ap-south-1"
}

# Define a Launch Template
resource "aws_launch_template" "my_launch_template" {
  name_prefix   = "my-template"
  image_id      = "ami-0c2af51e265bd5e0e"  # Update this to your desired AMI
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.my_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 10
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "My-ASG-Instance"
    }
  }
}

# Define Security Group
resource "aws_security_group" "my_sg" {
  name_prefix = "my-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define Auto Scaling Group
resource "aws_autoscaling_group" "my_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.my_subnet.id] # Your VPC Subnet
  health_check_type    = "EC2"
  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "my-asg-instance"
    propagate_at_launch = true
  }
}

# Define Load Balancer
resource "aws_elb" "my_elb" {
  name               = "my-elb"
  availability_zones = ["ap-south-1"]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = aws_autoscaling_group.my_asg.instances
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

# Subnet
resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}
