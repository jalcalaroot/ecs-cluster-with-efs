resource "aws_ecs_service" "nginx-efs-instance-service" {
  name            = "nginx-efs-instance-service"
  cluster         = "${var.ecs_cluster}"
  task_definition = "${aws_ecs_task_definition.nginx-efs-instance-task.arn}"
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
resource "aws_ecs_task_definition" "nginx-efs-instance-task" {
  family = "nginx-efs-instance-task"
  volume = {
    name      = "efs-instance"
    host_path = "/mnt/efs"
  }

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
    "mountPoints": [{
      "containerPath": "/var/ww/html",
      "sourceVolume": "efs-instance"
    }],
    "name": "nginx",
    "logConfiguration": {
    "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/nginx-efs-instance-task",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "nginx-efs-instance-task"
      }
    }
  }
]
EOF
}

resource "aws_cloudwatch_log_group" "nginx" {
  name = "/ecs/nginx-efs-instance-task"
}
