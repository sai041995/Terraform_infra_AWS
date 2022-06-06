
### since iam using AWS so its act as a provider and user cambruim is created using AWS console as a user

provider "aws" {
  region                  = "us-east-1"
  profile                 = "cambrium"
}

###Creating a VPC used IP Range for the VPC

resource "aws_vpc" "challenge_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "challenge"
  }
}

###Create a Public Subnet with auto public IP Assignment enabled in custom VPC to host webserver which can publicly accesble

resource "aws_subnet" "pub_subnet_east-1a" {
  depends_on = [
    aws_vpc.challenge_vpc
  ]
  vpc_id = aws_vpc.challenge_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub_subnet_east-1a"
  }
}

###Create a Private Subnet in case you need batabases server which can only access via bastion

resource "aws_subnet" "pvt_subnet_east-1b" {
  depends_on = [
    aws_vpc.challenge_vpc,
    aws_subnet.pub_subnet_east-1a
  ]
  vpc_id = aws_vpc.challenge_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  
  tags = {
    Name = "pvt_subnet_east-1b"
  }
}

###Create Internet gateway for the a vpc for the internet

resource "aws_internet_gateway" "challenge_IG" {
  depends_on = [
    aws_vpc.challenge_vpc,
    aws_subnet.pub_subnet_east-1a,
    aws_subnet.pvt_subnet_east-1b
  ]
  
  # VPC in which it has to be created!
  vpc_id = aws_vpc.challenge_vpc.id

  tags = {
    Name = "challenge_IG"
  }
}

### created route table to configure it to a public subnet which we already have webserver

resource "aws_route_table" "challenge_pub_rt" {
  depends_on = [
    aws_vpc.challenge_vpc,
    aws_internet_gateway.challenge_IG
  ]
  vpc_id = aws_vpc.challenge_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.challenge_IG.id
  }

  tags = {
    Name = "challenge_pub_rt"
  }
}

### In this step i attached Internet Gateway to a public subnet via route table

resource "aws_route_table_association" "RT-IG-Association" {

  depends_on = [
    aws_vpc.challenge_vpc,
    aws_subnet.pub_subnet_east-1a,
    aws_subnet.pvt_subnet_east-1b,
    aws_route_table.challenge_pub_rt
  ]

### Public Subnet ID

  subnet_id      = aws_subnet.pub_subnet_east-1a.id

### Route Table ID

  route_table_id = aws_route_table.challenge_pub_rt.id
}

### Created a NAT gate way which provides internet for a private subnet

resource "aws_eip" "Nat-Gateway-EIP" {
  depends_on = [
    aws_route_table_association.RT-IG-Association
  ]
  vpc = true
}

resource "aws_nat_gateway" "challenge_NAT_GATEWAY" {
  depends_on = [
    aws_eip.Nat-Gateway-EIP
  ]

  ### Allocating the Elastic IP to the NAT Gateway!

  allocation_id = aws_eip.Nat-Gateway-EIP.id
  
  ### Associating it in the Public Subnet!

  subnet_id = aws_subnet.pub_subnet_east-1a.id
  tags = {
    Name = "challenge_NAT_GATEWAY"
  }
}

### Created another route table for a NAT gateway

resource "aws_route_table" "challenge_pvt_rt" {
  depends_on = [
    aws_nat_gateway.challenge_NAT_GATEWAY
  ]

  vpc_id = aws_vpc.challenge_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.challenge_NAT_GATEWAY.id
  }

  tags = {
    Name = "challenge_pvt_rt"
  }

}

### In this step i attached NAT gateway to a private subnet via route table

resource "aws_route_table_association" "Nat-Gateway-RT-Association" {
  depends_on = [
    aws_route_table.challenge_pvt_rt
  ]

### Private Subnet ID for adding this route table to the DHCP server of Private subnet!

  subnet_id      = aws_subnet.pvt_subnet_east-1b.id

### Route Table ID

  route_table_id = aws_route_table.challenge_pvt_rt.id
}




### Security group for a webserver which allows traffic and to ssh 

resource "aws_security_group" "challange_sg"{
  depends_on = [
    aws_vpc.challenge_vpc,
    aws_subnet.pub_subnet_east-1a,
    aws_subnet.pub_subnet_east-1a
  ]
  name = "challange_sg"
  description = "test1"
  vpc_id = aws_vpc.challenge_vpc.id
  ingress{
     from_port = 80
     to_port = 80
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }

  ingress{
     from_port = 22
     to_port = 22
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]


  }

  egress {
     from_port = 0
     to_port = 0
     protocol = "-1"
     cidr_blocks = ["0.0.0.0/0"]

  }
  tags = {
      Name = "challange_sg"
      Owner = "me"
   }

}

### Created Load balancer which traffic will go trough it to a webserver

resource "aws_elb" "challengeelb" {
  name = "challengeelb"
  security_groups = [aws_security_group.challange_sg.id]
  subnets = [aws_subnet.pub_subnet_east-1a.id,aws_subnet.pvt_subnet_east-1b.id]
  
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

### Created Launch configuration for the auto scaling group


resource "aws_launch_configuration" "challenge_configuration" {
  name_prefix = "challenge_configuration"
image_id = "ami-0022f774911c1d690" 
  instance_type = "t2.micro"
  
security_groups = [aws_security_group.challange_sg.id]
  associate_public_ip_address = true
  user_data = <<EOF
#!/bin/bash
sudo su
yum update -y
yum install httpd -y
cd /var/www/html
echo "Cambrium challenge" > index.html
service httpd start
chkconfig httpd on
EOF
lifecycle {
    create_before_destroy = true
  }
}

### Created a autoscaling group to instances or webservers to highly available all the time

resource "aws_autoscaling_group" "challenge_web_server" {
  name = "${aws_launch_configuration.challenge_configuration.name}-asg"
  min_size             = 1
  desired_capacity     = 1
  max_size             = 2
  
  health_check_type    = "ELB"
  load_balancers = [
    "${aws_elb.challengeelb.id}"
  ]
launch_configuration = "${aws_launch_configuration.challenge_configuration.name}"
enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
metrics_granularity = "1Minute"
vpc_zone_identifier  = [
    "${aws_subnet.pub_subnet_east-1a.id}",
    "${aws_subnet.pvt_subnet_east-1b.id}"
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
