module task {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_fargate_task"
  region = var.region
  account_id = var.account_id
  cluster_id = var.cluster_id
  name = var.name
  unique_suffix = var.unique_suffix
  task_config = var.task_config
  security_groups = var.network_configuration.security_groups
  subnets = var.network_configuration.subnets
}

resource "aws_ecs_service" "service" {
  name            = "${var.name}${local.dash_suffix}"
  task_definition = module.task.task.arn
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
    assign_public_ip = var.network_configuration.assign_public_ip
    security_groups = var.network_configuration.security_groups
    subnets = var.network_configuration.subnets
  }
}

output role {
  value = module.task.role.role
}
