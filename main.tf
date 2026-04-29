provider "aws" {
  region = "eu-north-1"
}

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
    "arn:aws:elasticloadbalancing:eu-north-1:533267295128:targetgroup/backend-tg/723478a41669da30"
  ]

  launch_template {
  id      = aws_launch_template.backend_lt.id
  version = "$Latest"
}

resource "aws_launch_template" "backend_lt" {
  name = "backend-lt"

  image_id      = "ami-080254318c2d8932f"
  instance_type = "t3.micro"
  key_name      = "tannu-key"

  vpc_security_group_ids = [
    "sg-07e7495f3d026eda0"
  ]

  user_data = "IyEvYmluL2Jhc2gKYXB0IHVwZGF0ZSAteQphcHQgaW5zdGFsbCAteSBub2RlanMgbnBtCgpjYXQgPDxFT0YgPiAvaG9tZS91YnVudHUvYXBwLmpzCmNvbnN0IGh0dHAgPSByZXF1aXJlKCdodHRwJyk7CmNvbnN0IG9zID0gcmVxdWlyZSgnb3MnKTsKCmNvbnN0IHNlcnZlciA9IGh0dHAuY3JlYXRlU2VydmVyKChyZXEsIHJlcykgPT4gewogIHJlcy5zZXRIZWFkZXIoJ0NvbnRlbnQtVHlwZScsICd0ZXh0L3BsYWluOyBjaGFyc2V0PXV0Zi04Jyk7CiAgcmVzLmVuZCgnSGVsbG8gZnJvbSAnICsgb3MuaG9zdG5hbWUoKSk7Cn0pOwoKc2VydmVyLmxpc3Rlbig4MCwgJzAuMC4wLjAnKTsKRU9GCgpub2RlIC9ob21lL3VidW50dS9hcHAuanM="

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "backend-server"
    }
  }
}

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

resource "aws_autoscaling_policy" "backend_scaling_policy" {
  name                   = "backend-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = 100 # requests per target (we can tune later)

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      resource_label = "app/tannu-alb/d7dc8ac422bf873d/targetgroup/backend-tg/723478a41669da30"
    }
  }
}

resource "aws_cloudwatch_dashboard" "backend_dashboard" {
  dashboard_name = "backend-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ALB Request Count"
          region = "eu-north-1"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/tannu-alb/d7dc8ac422bf873d"]
          ]
          stat   = "Sum"
          period = 60
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Healthy Targets"
          region = "eu-north-1"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "targetgroup/backend-tg/723478a41669da30"]
          ]
          stat   = "Average"
          period = 60
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ASG Instances In Service"
          region = "eu-north-1"
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", "backend-asg"]
          ]
          stat   = "Average"
          period = 60
        }
      }

    ]
  })
}

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
    TargetGroup  = "targetgroup/backend-tg/723478a41669da30"
    LoadBalancer = "app/tannu-alb/d7dc8ac422bf873d"
  }

  alarm_description = "Alert when no healthy backend instances"

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_sns_topic" "alerts" {
  name = "backend-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "tannujha0610@gmail.com"
}
