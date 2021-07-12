variable "name_stem" {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable "protocol" {
  type = string
  default = "HTTP"
}

variable "route_selection_expression" {
  type = string
  default = "$request.method $request.path"
}

variable "cors_configuration" {
  type = list(object({
    allow_credentials = bool
    allow_headers = list(string)
    allow_methods = list(string)
    allow_origins = list(string)
    expose_headers = list(string)
    max_age = number
  }))
  default = []
}

variable system_id {
  type = object({
    security_scope = string
    subsystem_name = string
  })
}

locals {
  stage_name = "${var.system_id.security_scope}-${var.system_id.subsystem_name}"
}

variable "log_retention_period" {
  type = number
  default = 7
}

variable "lambda_routes" {
  type = list(object({
    route_key = string
    handler_arn = string
    handler_name = string
    authorizer = string 
  }))
  default = []
}

variable authorizers {
  type = map(object({
    name = string
    audience = list(string)
    issuer = string
    identity_sources = list(string)
  }))
  default = {}
}

variable domain_record {
  type = list(object({
    domain_name = string
    zone_name = string
  }))
  default = []
}

locals {
  log_format = var.protocol == "WEBSOCKET" ? "[ '$context.requestId' ] [ $context.requestTimeEpoch ] [ $context.identity.sourceIp ] [ $context.connectionId ] [ $context.eventType ] [ $context.status ] [ $context.routeKey ] [ $context.stage ] [ $context.integration.requestId ] [ $context.integration.latency ] [ $context.integration.status ] [ '$context.integration.error' ] [ $context.apiId ] [ $context.connectedAt ] [ $context.domainName ] [ $context.error.messageString ]" : "[ '$context.requestId' ] [ $context.requestTimeEpoch ] [ $context.identity.sourceIp ] [ $context.status ] [ $context.routeKey ] [ $context.stage ] [ $context.integration.requestId ] [ $context.integration.latency ] [ $context.integration.status ] [ '$context.integration.error' ] [ $context.apiId ] [ $context.domainName ] [ $context.error.messageString ]"
}
