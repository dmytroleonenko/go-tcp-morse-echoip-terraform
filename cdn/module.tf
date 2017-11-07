terraform {
  required_version                = ">= 0.10.8"
}

provider "aws" {
  region                          = "${var.region}"
}

data "aws_availability_zones" "available" {
  state                           = "available"
}

data "aws_route53_zone" "default" {
  name 	                           = "${var.r53_zone_name}"
}

data "aws_ami" "coreos" {
  most_recent                      = true
  owners                           = ["595879546273"]

  filter {
    name                           = "architecture"
    values                         = ["x86_64"]
  }

  filter {
    name                           = "virtualization-type"
    values                         = ["hvm"]
  }

  filter {
    name                           = "name"
    values                         = ["CoreOS-beta-*"]
  }
}

resource "aws_vpc" "main" {
  cidr_block                       = "${var.cidr_block}"
  assign_generated_ipv6_cidr_block = "true"
  enable_dns_support               = "true"
  enable_dns_hostnames             = "true"

  tags {
    Name                           = "cdn-${var.region}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id                           = "${aws_vpc.main.id}"

  tags = {
    Name                           = "cdn-${var.region}-igw"
  }
}

resource "aws_subnet" "public" {
  count                            = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                           = "${aws_vpc.main.id}"
  cidr_block                       = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  map_public_ip_on_launch          = true
  assign_ipv6_address_on_creation  = false
  availability_zone                = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags = {
    Name                           = "cdn-${element(data.aws_availability_zones.available.names, count.index)}-public"
  }
}

resource "aws_route_table" "public" {
  count                            = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                           = "${aws_vpc.main.id}"

  route {
    cidr_block                     = "0.0.0.0/0"
    gateway_id                     = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table_association" "public" {
  count                            = "${length(data.aws_availability_zones.available.names)}"
  subnet_id                        = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id                   = "${element(aws_route_table.public.*.id, count.index)}"
}

resource "aws_security_group" "default" {
  vpc_id                           = "${aws_vpc.main.id}"

  ingress {
    from_port                      = -1
    to_port                        = -1
    protocol                       = "icmp"
    cidr_blocks                    = ["0.0.0.0/0"]
  }

  egress {
    from_port                      = 0
    to_port                        = 0
    protocol                       = "-1"
    cidr_blocks                    = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "echoip-server" {
  vpc_id                           = "${aws_vpc.main.id}"

  ingress {
    from_port                      = -1
    to_port                        = -1
    protocol                       = "icmp"
    cidr_blocks                    = ["0.0.0.0/0"]
  }

  ingress {
    from_port                      = 9999
    to_port                        = 9999
    protocol                       = "tcp"
    cidr_blocks                    = ["0.0.0.0/0"]
  }

  ingress {
    from_port                      = 22
    to_port                        = 22
    protocol                       = "tcp"
    cidr_blocks                    = ["0.0.0.0/0"]
  }

  egress {
    from_port                      = 0
    to_port                        = 0
    protocol                       = "-1"
    cidr_blocks                    = ["0.0.0.0/0"]
  }

}

resource "aws_key_pair" "echoip" {
  key_name                         = "echoip-key"
  public_key                       = "${var.openssh_pub_key}"
}

resource "aws_lb" "echoip-lb" {
  name                             = "echoip-cdn-lb"
  internal                         = false
  load_balancer_type               = "network"
}

resource "aws_lb_target_group" "echoip-lb-tg" {
  name                             = "echoip-cdn"
  port                             = "9999"
  # tcp protocol is not supported as of 7th of Nov 2017. See https://github.com/terraform-providers/terraform-provider-aws/issues/1912
  # Needs to be dirty-hacked by editing aws provider sources and replacing the aws plugin
  protocol                         = "TCP"
  vpc_id                           = "${aws_vpc.main.id}"
}

resource "aws_lb_listener" "echoip-cdn-tcp" {
  load_balancer_arn                = "${aws_lb.echoip-lb.arn}"
  port                             = "${var.echoip_tcp_port}"
  protocol                         = "TCP"

  default_action {
    target_group_arn               = "${aws_lb_target_group.echoip-lb-tg.arn}"
    type                           = "forward"
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_echoip" {
  autoscaling_group_name           = "${aws_autoscaling_group.echoip-cdn.id}"
  alb_target_group_arn             = "${aws_lb_target_group.echoip-lb-tg.arn}"
}

resource "aws_launch_configuration" "echoip-cdn" {
  name_prefix                      = "cdn-"
  image_id                         = "${data.aws_ami.coreos.id}"
  instance_type                    = "${var.instance_type}"
  security_groups                  = ["${aws_security_group.echoip-server.id}"]
  key_name                         = "${aws_key_pair.echoip.key_name}"
  user_data                        = "${file("cdn/cloud-config.txt")}"

  lifecycle {
    create_before_destroy          = true
  }

  root_block_device {
    volume_type                    = "gp2"
    volume_size                    = "8"
  }
}

resource "aws_autoscaling_group" "echoip-cdn" {
  vpc_zone_identifier              = ["${aws_subnet.public.*.id}"]
  name                             = "echoip-cdn"
  max_size                         = "${var.max_servers_per_region}"
  min_size                         = "${var.min_servers_per_region}"
  health_check_grace_period        = 200
  health_check_type                = "EC2"
  desired_capacity                 = "${var.min_servers_per_region}"
  force_delete                     = true
  launch_configuration             = "${aws_launch_configuration.echoip-cdn.name}"
  
  tag {
    key                            = "Name"
    value                          = "echoip-cdn"
    propagate_at_launch            = true
  }
}

resource "aws_autoscaling_policy" "echoip-scale-up" {
  name                             = "echoip-scale-up"
  scaling_adjustment               = 1
  adjustment_type                  = "ChangeInCapacity"
  cooldown                         = 300
  autoscaling_group_name           = "${aws_autoscaling_group.echoip-cdn.name}"
}

resource "aws_autoscaling_policy" "echoip-scale-down" {
  name                             = "echoip-scale-down"
  scaling_adjustment               = -1
  adjustment_type                  = "ChangeInCapacity"
  cooldown                         = 300
  autoscaling_group_name           = "${aws_autoscaling_group.echoip-cdn.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-high" {
  alarm_name                       = "cpu-util-high-echoip-cdn"
  comparison_operator              = "GreaterThanOrEqualToThreshold"
  evaluation_periods               = "2"
  metric_name                      = "CPUUtilization"
  namespace                        = "AWS/EC2"
  period                           = "300"
  statistic                        = "Average"
  threshold                        = "80"
  alarm_description                = "This metric monitors ec2 cpu high utilization on echoip-cdn instances"
  alarm_actions = [
    "${aws_autoscaling_policy.echoip-scale-up.arn}"
  ]
  dimensions {
    AutoScalingGroupName           = "${aws_autoscaling_group.echoip-cdn.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "memory-low" {
  alarm_name                       = "cpu-util-low-echoip-cdn"
  comparison_operator              = "LessThanOrEqualToThreshold"
  evaluation_periods               = "2"
  metric_name                      = "CPUUtilization"
  namespace                        = "AWS/EC2"
  period                           = "300"
  statistic                        = "Average"
  threshold                        = "40"
  alarm_description                = "This metric monitors ec2 cpu low utilization on echoip-cdn instances"
  alarm_actions = [
    "${aws_autoscaling_policy.echoip-scale-down.arn}"
  ]
  dimensions {
    AutoScalingGroupName           = "${aws_autoscaling_group.echoip-cdn.name}"
  }
}


resource "aws_route53_record" "cdn" {
  zone_id                          = "${data.aws_route53_zone.default.zone_id}"
  name                             = "${format("%s.%s", var.r53_domain_name, data.aws_route53_zone.default.name)}"
  type                             = "CNAME"
  ttl                              = "60"
  records                          = ["${aws_lb.echoip-lb.*.dns_name}"]
  set_identifier                   = "echoip-cdn-${var.region}"

  latency_routing_policy {
    region                         = "${var.region}"
  }
}
