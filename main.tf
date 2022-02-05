provider "aws" {
  region  = "ap-south-1"
  profile = "" 
}
data "aws_acm_certificate" "example" {
  domain      = "" #domain
  types       = ["DNS", "AMAZON_ISSUED"]
  statuses    = ["ISSUED"]
  most_recent = true
}
resource "aws_lb_listener_certificate" "example" {
  listener_arn    = data.aws_lb_listener.front_end.arn
  certificate_arn = data.aws_acm_certificate.example.arn
}
data "aws_lb" "front_end" {
  name = "ALB" #add in Load Balancer
}
resource "aws_lb_target_group" "task-definition-fg" {
  name        = "task-definition-fg-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-name" #vpc
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 10
  }
}
data "aws_lb_listener" "front_end" {
  load_balancer_arn = data.aws_lb.front_end.arn
  port              = "443"
}
resource "aws_lb_listener_rule" "host_based_weighted_routing" {
  listener_arn = data.aws_lb_listener.front_end.arn
  priority     = 1867 #priority should be unique for every new setup
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.task-definition-fg.arn
  }
  condition {
    host_header {
      values = ["task-definition.finflux.io"]
    }
  }
}
#task definition is created => finflux-task-definition-fg
data "aws_ecs_cluster" "test" {
  cluster_name = "" #add cluster name
}
data "aws_ecs_task_definition" "ecs-task-definition" {
  task_definition = "finflux-task-definition-fg" 
}
resource "aws_ecs_service" "task-definition-fg-ecs" {
  name                               = "task-definition-fg"              #service name
  cluster                            = data.aws_ecs_cluster.test.id #select non prod
  task_definition                    = data.aws_ecs_task_definition.ecs-task-definition.id
  scheduling_strategy                = "REPLICA"
  desired_count                      = 1
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 7200
  # launch_type                        = "FARGATE"
  network_configuration {
    assign_public_ip = true
    subnets          = ["subnets"] #add subnets
    security_groups  = ["sg"] #add SG
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.task-definition-fg.arn
    container_name   = "web"
    container_port   = 80
  }
}

