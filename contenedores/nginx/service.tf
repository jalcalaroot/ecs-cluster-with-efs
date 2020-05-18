resource "aws_ecs_service" "tomcat" {
  name            = "tomcat"
  cluster         = "${var.ecs_cluster}"
  task_definition = "${aws_ecs_task_definition.tomcat.arn}"
  desired_count   = 1
  iam_role        = "arn:aws:iam::266144297920:role/CCBprod-role"
  load_balancer {
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:266144297920:targetgroup/test/8c214464144d4844"
    container_name   = "tomcat"
    container_port   = "8080"
  }
  lifecycle {
    ignore_changes = ["task_definition"]
  }
}
resource "aws_ecs_task_definition" "tomcat" {
  family = "tomcat"
  container_definitions = <<EOF
[
  {
    "portMappings": [
      {
        "hostPort": 8080,
        "protocol": "tcp",
        "containerPort": 8080
      }
    ],
    "cpu": 256,
    "memory": 300,
    "image": "tomcat",
    "essential": true,
    "name": "tomcat",
    "logConfiguration": {
    "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${var.ecs_cluster}/ecs/tomcat",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
}
resource "aws_cloudwatch_log_group" "tomcat" {
  name = "${var.ecs_cluster}/ecs/tomcat"
}
