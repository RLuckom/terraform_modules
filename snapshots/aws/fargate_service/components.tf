resource "aws_ecs_task_definition" "task" {
  family = "${var.name}${local.dash_suffix}"
  execution_role_arn = module.svc_role.role.arn
  container_definitions = jsonencode([for container in var.task_config.containers : 
    {
      name = container.name,
      image = "${container.image.name}:${container.image.tag}",
      portMappings = [for port_mapping in container.port_mappings : {
        hostPort = port_mapping.host_port
        containerPort = port_mapping.container_port
        protocol = port_mapping.protocol
      }]
      dependsOn = [for depends_on in container.depends_on : {
        condition = depends_on.condition
        containerName = depends_on.container_name
      }]
      essential = container.essential
      healthCheck = container.health_check.command == null ? null : container.health_check
      command = container.command
      secrets = [for k, v in container.secrets : {
        name = k
        valueFrom = v
      }],
      environment = [for k, v in container.environment : {
        name = k
        value = v
      }],
      memory = container.resources.mem
      cpu = container.resources.cpu
      mountPoints = []
      volumesFrom = []
      logConfiguration = {
        logDriver = "awslogs",
        options = zipmap(["awslogs-region", "awslogs-group", "awslogs-stream-prefix"], [var.region, local.log_group_name, "ecs"])
      }
    }
  ])
  cpu = var.task_config.resources.cpu
  memory = var.task_config.resources.mem
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
}

resource "aws_cloudwatch_log_group" "web" {
  name = local.log_group_name
}

locals {
  log_group_name = "/ecs/${var.name}${local.dash_suffix}"
}

locals {
  ecs_task_execution_permissions = [{
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"]
  }, {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:${local.log_group_name}:*:*"
    ]
  }]
}

module "svc_role" {
  source = "../permissioned_role"
  role_name = var.name
  account_id = var.account_id
  unique_suffix = var.unique_suffix
  role_policy = concat(local.ecs_task_execution_permissions, [local.parameter_permissions_needed])
  principals = [{
    type = "Service"
    identifiers = ["ecs-tasks.amazonaws.com"]
  }]
}

resource "aws_ecs_service" "service" {
  name            = "${var.name}${local.dash_suffix}"
  task_definition = aws_ecs_task_definition.task.arn
  cluster         = var.cluster_id
  launch_type     = "FARGATE"
  dynamic "load_balancer" {
    for_each = var.load_balancer_configs
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }
  desired_count = var.num_tasks
  network_configuration {
    assign_public_ip = false
    security_groups = var.security_groups
    subnets = var.subnets
  }
}

output role {
  value = module.svc_role.role
}
