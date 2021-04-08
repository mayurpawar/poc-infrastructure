# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a VPC
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name = join("", [var.project, " vpc"])
  cidr = join("", [var.cidr_first_two_blocks, ".0.0/16"])

  azs             = [
    join("", [var.region, "a"]),
    join("", [var.region, "b"]),
    join("", [var.region, "c"])
  ]

  private_subnets = [
    join("", [var.cidr_first_two_blocks, ".1.0/24"]),
    join("", [var.cidr_first_two_blocks, ".2.0/24"]),
    join("", [var.cidr_first_two_blocks, ".3.0/24"])
  ]
  public_subnets  = [
    join("", [var.cidr_first_two_blocks, ".101.0/24"]),
    join("", [var.cidr_first_two_blocks, ".102.0/24"]),
    join("", [var.cidr_first_two_blocks, ".103.0/24"])
  ]

  enable_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }

  vpc_tags = {
    Name = join("", [var.project, " vpc"])
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a security group for the load balancer
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_security_group" "load_balancer_security_group" {
  name        = "all_internet_traffic"
  description = "Allow traffic from internet"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating load balancer
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_alb" "application_load_balancer" {
  name               = join("", [var.environment, "appserver--alb"])
  load_balancer_type = "application"
  subnets = module.vpc.public_subnets
  security_groups = [
    aws_security_group.load_balancer_security_group.id
  ]
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Updating or creating route 53 record to point to new elb
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_route53_record" "route_to_alb" {
  zone_id = var.hostedZoneID
  name    = var.environment
  type    = "CNAME"
  ttl     = "300"
  records = [
    aws_alb.application_load_balancer.dns_name
  ]
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a target group for the load balancer
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id     = module.vpc.vpc_id

  health_check {
    matcher = "200"
    path    = "/"
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a listner for target group
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a listner rule for target group
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a ECS cluster for application
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

module "ecs_cluster" {
  source  = "infrablocks/ecs-cluster/aws"
  version = "3.4.0"

  region     = var.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  component             = join("", [var.project, "-cluster"])
  deployment_identifier = var.environment

  cluster_name          = join("", [var.project, "-cluster"])
  cluster_instance_type = var.app_server_cluster_instance_type

  cluster_minimum_size     = var.appserver_cluster_minimum_size
  cluster_maximum_size     = var.appserver_cluster_maximum_size
  cluster_desired_capacity = var.appserver_cluster_desired_capacity

  security_groups = [
    aws_security_group.load_balancer_security_group.id
  ]
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a task definition for application
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# IAM policy for APP for retrieving database secrets
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_iam_policy" "getDatabaseCredentials_InlinePolicy" {
  name        = "getDatabaseCredentials_InlinePolicy"
  path        = "/"
  description = "Inline policy to get DB credentials from secret manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Effect = "Allow"
        Resource = [
          var.secretManagerArn,
          var.kmsArn
        ]
      },
    ]
  })
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a role for a task definition
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy_attachment" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Attaching database policy to task definition role
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_inlinePolicyAttachment" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = aws_iam_policy.getDatabaseCredentials_InlinePolicy.arn
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a task definition for an app
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_ecs_task_definition" "app_task" {
  family = join("", [var.project, "-task"])
  container_definitions = jsonencode([
    {
      name : "my-container",
      image : "mayurpawar/ved:5",
      essential : true,
      portMappings : [
        {
          hostPort : 0,
          containerPort : 80
        }
      ],
      secrets : [
        {
          name : "credentials",
          valueFrom : var.secretManagerArn
        }
      ],

      logConfiguration : {
        logDriver : "awslogs",
        options : {
          "awslogs-create-group" : "true"
          "awslogs-group" : join("", ["/ecs/", var.project, "-task"]),
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "ecs"
        }
      }

      cpu : 0
    }
  ])

  requires_compatibilities = ["EC2"]
  memory                   = 300
  cpu                      = 300
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a security group for the load balancer:
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_ecs_service" "app_service" {
  name                               = join("", [var.project, "-service"])
  cluster                            = module.ecs_cluster.cluster_id
  task_definition                    = aws_ecs_task_definition.app_task.arn
  launch_type                        = "EC2"
  scheduling_strategy                = "REPLICA"
  desired_count                      = var.appserver_tasks_desired_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0

  ordered_placement_strategy {
    type = var.ecs_service_ordered_placement_strategy
  }
  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name = jsondecode(aws_ecs_task_definition.app_task.container_definitions)[0].name
    container_port   = 80
  }
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a security group for the load balancer
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_security_group" "webserver_load_balancer_security_group" {
  name        = "webserver_all_internet_traffic"
  description = "Allow traffic from internet"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating load balancer
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_alb" "webserver_application_load_balancer" {
  name               = join("", [var.environment, "-webserver-alb"])
  load_balancer_type = "application"
  subnets = module.vpc.public_subnets
  security_groups = [
    aws_security_group.webserver_load_balancer_security_group.id
  ]
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a target group for the load balancer
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_lb_target_group" "webserver_target_group" {
  name        = "webserver-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id     = module.vpc.vpc_id

  health_check {
    matcher = "200"
    path    = "/"
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a listner for target group
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_lb_listener" "webserver_listener" {
  load_balancer_arn = aws_alb.webserver_application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver_target_group.arn
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a listner rule for target group
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_lb_listener_rule" "webserver_static" {
  listener_arn = aws_lb_listener.webserver_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a ECS cluster for application
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

module "webserver_ecs_cluster" {
  source  = "infrablocks/ecs-cluster/aws"
  version = "3.4.0"

  region     = var.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  component             = join("", [var.project, "-webserver-cluster"])
  deployment_identifier = var.environment

  cluster_name          = join("", [var.project, "-webserver-cluster"])
  cluster_instance_type = var.app_server_cluster_instance_type

  cluster_minimum_size     = var.appserver_cluster_minimum_size
  cluster_maximum_size     = var.appserver_cluster_maximum_size
  cluster_desired_capacity = var.appserver_cluster_desired_capacity

  security_groups = [
    aws_security_group.webserver_load_balancer_security_group.id
  ]
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a task definition for application
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_iam_role" "webserver_ecsTaskExecutionRole" {
  name               = "webserver_ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

//data "aws_iam_policy_document" "assume_role_policy" {
//  statement {
//    actions = ["sts:AssumeRole"]
//
//    principals {
//      type        = "Service"
//      identifiers = ["ecs-tasks.amazonaws.com"]
//    }
//  }
//}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a role for a task definition
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_iam_role_policy_attachment" "webserver_ecsTaskExecutionRole_policy_attachment" {
  role       = aws_iam_role.webserver_ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a task definition for an app
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_ecs_task_definition" "webserver_app_task" {
  family = join("", [var.project, "-task"])
  container_definitions = jsonencode([
    {
      name : "my-webserver-container",
      image : "nginx:1.19.9",
      essential : true,
      portMappings : [
        {
          hostPort : 0,
          containerPort : 80
        }
      ],
      logConfiguration : {
        logDriver : "awslogs",
        options : {
          "awslogs-create-group" : "true"
          "awslogs-group" : join("", ["/ecs/", var.project, "-task"]),
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "ecs"
        }
      }
    }
  ])

  requires_compatibilities = ["EC2"]
  memory                   = 300
  cpu                      = 300
  execution_role_arn       = aws_iam_role.webserver_ecsTaskExecutionRole.arn
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a security group for the load balancer:
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

resource "aws_ecs_service" "webserver_app_service" {
  name                               = join("", [var.project, "-service"])
  cluster                            = module.webserver_ecs_cluster.cluster_id
  task_definition                    = aws_ecs_task_definition.webserver_app_task.arn
  launch_type                        = "EC2"
  scheduling_strategy                = "REPLICA"
  desired_count                      = var.appserver_tasks_desired_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0

  ordered_placement_strategy {
    type = var.ecs_service_ordered_placement_strategy
  }
  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webserver_target_group.arn
    container_name = jsondecode(aws_ecs_task_definition.webserver_app_task.container_definitions)[0].name
    container_port   = 80
  }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creating a security group for the load balancer:
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #