#Cluster ECS##

resource "aws_ecs_cluster" "ecs" {
  name = "${var.ecs_cluster}"

  lifecycle {
    create_before_destroy = true
  }
}

#----------------------------------------------------
#SG
resource "aws_security_group" "sgecscluster" {
  name = "${var.ecs_cluster}-sg-ecscluster"
  description = "sgecscluster"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
# SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"]
  }
# HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"]
  }

# https
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"]
  }


  tags = {
    Name = "${var.ecs_cluster}-sg-ecscluster"
    env  = "terraform"
  }
}

#-----------------------------------------------
#Key Pair
resource "aws_key_pair" "key" {
  key_name = "${var.ecs_cluster}-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIXOwvNd2/k+uwQ3h5kcQpbRWVQpTf0iurGHqHEvlTRlT1T8NzehAU3+2dCJ6PzWxYTCqY/XVLzCR5BM+yaiRn+rLQRN0F4NKJpKXhEMz2Ia7V5MTIS3TRKoG2wLZu3NrDrlHOXRzrsuVeVAPv+eYHFrM5WOJjdmfSRBlTwgKtsZbRHo0nloXcjY6HHqabBJZVe/0rXTMkOyHUXJcRLkyB1u0aahsMiIt5l0156xlphXGJkkBuR1PXl2Dghliy6U61vRybYr8Pfh82lN7vIJIEAdMreGEZhaLKk01Ck1PWXn5Ke3rdu9VcV9j1EbvKNtIgUSbrXeKbjFOGOxbuxZ0giG+veoiOKCREW9WDbMezKpp59SpXfzzglIYVUHddrcY4ziJ8cxEJrOjZGPp0M74PYN3YhUgTzJJqfpxNRNGvJ7SboiK8bwi7e9Mrbk01obtmrdFsz9KIkuphuPxZcuPuP9kTN4Tiijudm1nwMfondNQ48DYeIUKxpxVpEcTi9Oc= terraform@jalcalaroot-VIT-P2412"
}

#-------------------------------------------------
# IAM Roles

resource "aws_iam_role" "iam_role" {
  name = "${var.ecs_cluster}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

#atachando policys
resource "aws_iam_role_policy_attachment" "ecs-service-role" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy_attachment" "ecs-service-for-ec2-role" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "efs" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
}
resource "aws_iam_instance_profile" "ecs-instance-profile" {
  name  = "${var.ecs_cluster}-ecs"
  role = "${aws_iam_role.iam_role.name}"
}
#--------------------------------------------------------------------------------

#SG-ALB	
resource "aws_security_group" "sgalb" {
  name = "${var.ecs_cluster}-sg-alb"
  description = "sgalb"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
# HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

# https
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ecs_cluster}-sg-alb"
    env  = "terraform"
  }
}

#---------------------------------------------------

resource "aws_alb" "ecs-load-balancer" {
    name                = "${var.ecs_cluster}-load-balancer"
    security_groups     = ["${aws_security_group.sgalb.id}"]
    subnets             = ["${var.subnet_1}", "${var.subnet_2}", "${var.subnet_3}"]

    tags {
      Name = "${var.ecs_cluster}-ecs-load-balancer"
    }
}

resource "aws_alb_target_group" "ecs-target-group" {
    name                = "${var.ecs_cluster}-target-group"
    port                = "80"
    protocol            = "HTTP"
    vpc_id              = "${var.vpc_id}"

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = "5"
    }

lifecycle {
    create_before_destroy = true
  }

  depends_on = ["aws_alb.ecs-load-balancer"] // HERE!
}


resource "aws_alb_listener" "alb-listener" {
    load_balancer_arn = "${aws_alb.ecs-load-balancer.arn}"
    port              = "80"
    protocol          = "HTTP"

    default_action {
        target_group_arn = "${aws_alb_target_group.ecs-target-group.arn}"
        type             = "forward"
    }
}

#---------------------------------------------------------------------------
#EFS

resource "aws_security_group" "sgefs" {
  name = "${var.ecs_cluster}-sg-efs"
  description = "sgefs"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

# EFS2049
  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"]
  }

  tags = {
    Name = "${var.ecs_cluster}-sg-efs"
    env  = "terraform"
  }
}



resource "aws_efs_file_system" "efs" {
  creation_token   = "${var.ecs_cluster}.efs"
  performance_mode = "generalPurpose"

    lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
tags = {
    Name = "${var.ecs_cluster}.efs"
  }
}
resource "aws_efs_mount_target" "a" {
  file_system_id  = "${aws_efs_file_system.efs.id}"
  subnet_id       = "${var.subnet_efs}"
  security_groups = ["${aws_security_group.sgecscluster.id}", "${aws_security_group.sgefs.id}"]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = "${aws_efs_file_system.efs.id}"
  subnet_id       = "${var.subnet_efs2}"
  security_groups = ["${aws_security_group.sgecscluster.id}", "${aws_security_group.sgefs.id}"]
}

resource "aws_efs_mount_target" "c" {
  file_system_id  = "${aws_efs_file_system.efs.id}"
  subnet_id       = "${var.subnet_efs3}"
  security_groups = ["${aws_security_group.sgecscluster.id}", "${aws_security_group.sgefs.id}"]
}



#---------------------------------------------------------------------------
resource "aws_launch_configuration" "ecs-launch-configuration" {
    name                        = "${var.ecs_cluster}-ecs-launch-configuration"
    image_id                    = "ami-00afc256a955c31b5"
    instance_type               = "${var.instance_type}"
    iam_instance_profile        = "${aws_iam_instance_profile.ecs-instance-profile.arn}"

    root_block_device {
      volume_type = "gp2"
      volume_size = 30
      delete_on_termination = true
    }

    lifecycle {
      create_before_destroy = true
    }

    security_groups             = ["${aws_security_group.sgecscluster.id}", "${aws_security_group.sgalb.id}"]
    key_name                    = "${var.ecs_cluster}-key"
    user_data                   = <<EOF
                                  #!/bin/bash
                                  echo ECS_CLUSTER=${var.ecs_cluster} >> /etc/ecs/ecs.config
                                  yum -y update
                                  yum -y upgrade
                                  yum install -y docker aws-cli python27-pip ecs-init bind-utils awslogs jq nfs-utils
                                  python -m pip install --upgrade pip
                                  python -m pip install --upgrade boto3
                                  python -m pip install --upgrade requests
                                  curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
                                  service docker start
                                  start ecs
                                  service awslogsd start
                                  yum install -y amazon-efs-utils nfs-utils jq htop screen
                                  aws configure set preview.efs true
                                  EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
                                  EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
                                  EFS_FILE_SYSTEM_ID=`aws efs describe-file-systems --region $EC2_REGION | jq '.FileSystems[]' | jq 'select(.Name=="${var.ecs_cluster}.efs")' | jq -r '.FileSystemId'`
                                  mkdir /mnt/efs
                                  sudo chown ec2-user:ec2-user /mnt/efs
                                  sudo chmod 777 /mnt/efs
                                  sudo mount -t efs $EFS_FILE_SYSTEM_ID:/ /mnt/efs
                                  echo $EFS_FILE_SYSTEM_ID:/ /mnt/efs efs defaults,_netdev 0 0 >> /etc/fstab
                                  sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
                                  sudo systemctl enable amazon-ssm-agent
                                  sudo systemctl start amazon-ssm-agent
                                  echo "config realizada" >> /home/ec2-user/config.txt
                                  EOF
}

resource "aws_autoscaling_group" "ecs-autoscaling-group" {
    name                        = "${var.ecs_cluster}-ecs-autoscaling-group"
    max_size                    = "${var.max_instance_size}"
    min_size                    = "${var.min_instance_size}"
    desired_capacity            = "${var.desired_capacity}"
    vpc_zone_identifier         = ["${var.subnet_4}", "${var.subnet_5}", "${var.subnet_6}"]
    launch_configuration        = "${aws_launch_configuration.ecs-launch-configuration.name}"
    health_check_type           = "ELB"
tag {
    key = "Name"
    value = "node-cluster-${var.ecs_cluster}"
    propagate_at_launch = true
  }
}
#-------------------------------------------------------------------

