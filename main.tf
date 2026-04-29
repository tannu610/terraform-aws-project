provider "aws" {
  region = "eu-north-1"
}

<<<<<<< HEAD
resource "aws_instance" "backend" {
  ami                    = "ami-080254318c2d8932f"
  instance_type          = "t3.micro"
  subnet_id              = "subnet-09798a12b702c62f3"
  key_name               = "tannu-key"
  vpc_security_group_ids = ["sg-07e7495f3d026eda0"]

  tags = {
    Name = "backend-server"
  }
}

resource "aws_autoscaling_group" "backend_asg" {
  name             = "backend-asg"
  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  vpc_zone_identifier = [
    "subnet-09798a12b702c62f3",
    "subnet-09e5479b3a55c345d"
  ]

  health_check_type         = "EC2"
  health_check_grace_period = 300

  target_group_arns = [
  aws_lb_target_group.backend_tg.arn
]

  launch_template {
  id      = aws_launch_template.backend_lt.id
  version = "$Latest"
}

=======
# -----------------------------
# Launch Template
# -----------------------------
>>>>>>> be99a64 (updated terraform config)
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "backend-lt-"
  image_id      = "ami-080254318c2d8932f"
  instance_type = "t3.micro"
  key_name      = "tannu-key"

  vpc_security_group_ids = ["sg-07e7495f3d026eda0"]

  user_data = "IyEvYmluL2Jhc2gKYXB0IHVwZGF0ZSAteQphcHQgaW5zdGFsbCAteSBub2RlanMgbnBtCgpjYXQgPDxFT0YgPiAvaG9tZS91YnVudHUvYXBwLmpzCmNvbnN0IGh0dHAgPSByZXF1aXJlKCdodHRwJyk7CmNvbnN0IG9zID0gcmVxdWlyZSgnb3MnKTsKCmNvbnN0IHNlcnZlciA9IGh0dHAuY3JlYXRlU2VydmVyKChyZXEsIHJlcykgPT4gewogIHJlcy5zZXRIZWFkZXIoJ0NvbnRlbnQtVHlwZScsICd0ZXh0L3BsYWluOyBjaGFyc2V0PXV0Zi04Jyk7CiAgcmVzLmVuZCgnSGVsbG8gZnJvbSAnICsgb3MuaG9zdG5hbWUoKSk7Cn0pOwoKc2VydmVyLmxpc3Rlbig4MCwgJzAuMC4wLjAnKTsKRU9GCgpub2RlIC9ob21lL3VidW50dS9hcHAuanM="

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "backend-server"
    }
  }
}

# -----------------------------
# Target Group
# -----------------------------
resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-0c1866dfeb787dd92"
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

# -----------------------------
# Application Load Balancer
# -----------------------------
resource "aws_lb" "backend_alb" {
  name               = "tannu-alb"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    "subnet-09798a12b702c62f3",
    "subnet-09e5479b3a55c345d"
  ]

  security_groups = ["sg-07e7495f3d026eda0"]
}

# -----------------------------
# Listener
# -----------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# -----------------------------
# Auto Scaling Group
# -----------------------------
resource "aws_autoscaling_group" "backend_asg" {
  name             = "backend-asg"
  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  vpc_zone_identifier = [
    "subnet-09798a12b702c62f3",
    "subnet-09e5479b3a55c345d"
  ]

  health_check_type         = "EC2"
  health_check_grace_period = 300

  target_group_arns = [
    aws_lb_target_group.backend_tg.arn
  ]

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

# -----------------------------
# Scaling Policy
# -----------------------------
resource "aws_autoscaling_policy" "backend_scaling_policy" {
  name                   = "backend-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = 100

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      resource_label = "${aws_lb.backend_alb.arn_suffix}/${aws_lb_target_group.backend_tg.arn_suffix}"
    }
  }
}

# -----------------------------
# SNS Topic
# -----------------------------
resource "aws_sns_topic" "alerts" {
  name = "backend-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "tannujha0610@gmail.com"
}

# -----------------------------
# CloudWatch Alarm
# -----------------------------
resource "aws_cloudwatch_metric_alarm" "backend_unhealthy_alarm" {
  alarm_name          = "backend-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1

  dimensions = {
    TargetGroup  = aws_lb_target_group.backend_tg.arn_suffix
    LoadBalancer = aws_lb.backend_alb.arn_suffix
  }

  alarm_description = "Alert when no healthy backend instances"

  alarm_actions = [aws_sns_topic.alerts.arn]
}