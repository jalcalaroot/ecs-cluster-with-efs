resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = "${var.ecs_cluster}"
  task_definition = "${aws_ecs_task_definition.nginx.arn}"
  desired_count   = 1
  iam_role        = "arn:aws:iam::710334221761:role/main-role"
  load_balancer {
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:710334221761:targetgroup/main-target-group/06db79dd42a28f7e"
    container_name   = "nginx"
    container_port   = "80"
  }
  lifecycle {
    ignore_changes = ["task_definition"]
  }
}
resource "aws_ecs_task_definition" "nginx" {
  family = "nginx"

  container_definitions = <<EOF
[
  {
    "portMappings": [
      {
        "hostPort": 80,
        "protocol": "tcp",
        "containerPort": 80
      }
    ],
    "cpu": 256,
    "memory": 300,
    "image": "nginx:latest",
    "essential": true,
    "name": "nginx",
    "logConfiguration": {
    "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs-demo/nginx",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
}

resource "aws_cloudwatch_log_group" "nginx" {
  name = "/ecs-demo/nginx"
}
