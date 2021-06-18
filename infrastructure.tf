resource "aws_vpc" "anjoshi-vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "anjoshi-VPC"
    env = "test"
  }
}

resource "aws_subnet" "public_us_east_1a" {
  vpc_id     = aws_vpc.anjoshi-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet us-east-1a"
  }
}

resource "aws_subnet" "public_us_east_1b" {
  vpc_id     = aws_vpc.anjoshi-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public Subnet us-east-1b"
  }
}

resource "aws_internet_gateway" "anjoshi-vpc_igw" {
  vpc_id = aws_vpc.anjoshi-vpc.id

  tags = {
    Name = "anjoshi-VPC - Internet Gateway"
  }
}

resource "aws_route_table" "vpc_public_rt" {
    vpc_id = aws_vpc.anjoshi-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.anjoshi-vpc_igw.id
    }

    tags = {
        Name = "Public Subnets Route Table for anjoshi-VPC"
    }
}

resource "aws_route_table_association" "anjoshi-vpc_us_east_1a_public" {
    subnet_id = aws_subnet.public_us_east_1a.id
    route_table_id = aws_route_table.vpc_public_rt.id
}

resource "aws_route_table_association" "anjoshi-vpc_us_east_1b_public" {
    subnet_id = aws_subnet.public_us_east_1b.id
    route_table_id = aws_route_table.vpc_public_rt.id
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id = aws_vpc.anjoshi-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP Security Group"
  }
}

variable "ssh-key-value" {
  default = "<ENTER YOUR SSH PUBLIC KEY HERE>"
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = var.ssh-key-value
}

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = "ami-0947d2ba12ee1ff75" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type = "t2.micro"

  security_groups = [ aws_security_group.allow_http.id ]
  associate_public_ip_address = true

  key_name = aws_key_pair.ssh-key.key_name

  user_data = <<USER_DATA
#!/bin/bash
yum update
yum -y install nginx
echo "$(curl http://169.254.169.254/latest/meta-data/local-ipv4)" > /usr/share/nginx/html/index.html
chkconfig nginx on
service nginx start
  USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.allow_http.id
  ]
  subnets = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id
  ]

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.web.name

  vpc_zone_identifier  = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}


resource "aws_route53_zone" "r53-hosted-zone" {
  name = "anjoshi-test.com"
  comment = "r53-hosted-zone public zone"
  provider = aws
}

resource "aws_route53_record" "r53-record" {
  zone_id = aws_route53_zone.r53-hosted-zone.zone_id
  name    = "server1.anjoshi-test.com"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_elb.web_elb.dns_name]
}

output "elb_dns_name" {
  value = aws_elb.web_elb.dns_name
}

output "r53-entry-record" {
  value =  aws_route53_record.r53-record.name
}


output "r53-hosted-zone-dns-servers" {
  value = aws_route53_zone.r53-hosted-zone.name_servers
}
