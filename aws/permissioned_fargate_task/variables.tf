variable region {
  type = string
  default = "us-east-1"
}

variable account_id {
  type = string
}

variable tags {
  type = map(string)
  default = {}
}

variable cluster_id {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable task_config {
  type = object({
    resources = object({
      mem = number
      cpu = number
    })
    containers = list(object({
      name = string
      command = list(string)
      essential = bool
      depends_on = list(object({
        condition = string
        container_name = string
      }))
      health_check = object({
        command = list(string)
        interval = number
        retries = number
        timeout = number
        startPeriod = number
      })
      image = object({
        name = string
        tag = string
      })
      resources = object({
        mem = number
        cpu = number
      })
      port_mappings = list(object({
        container_port = number
        host_port = number
        protocol = string
      }))
      secrets = map(string)
      environment = map(string)
    }))
  })
}

variable name {
  type = string
}

variable security_groups {
  type = list(string)
  default = []
}

variable subnets {
  type = list(string)
  default = []
}

locals {
  dash_suffix = var.unique_suffix == "" ? "" : "-${var.unique_suffix}"
  parameters_needed = flatten([for container in var.task_config.containers : values(container.secrets)])
  parameter_permissions_needed = {
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [for param in local.parameters_needed : "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${param}"]
  }
}
