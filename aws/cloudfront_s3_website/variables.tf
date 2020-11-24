variable "route53_zone_name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "domain_name_prefix" {
  type = string
}

variable "subject_alternative_names" {
  type = list(string)
}

variable "allowed_origins" {
  type = list(string)
  default = []
}

variable "compress" {
  default = true
}

variable "default_cloudfront_ttls" {
  type = object({
    min = number
    default = number
    max = number
  })
  default = {
    min = 0
    default = 3600
    max = 86400
  }
}

variable "lambda_origins" {
  type = list(object({
    id = string
    path = string
    site_path = string
    apigateway_path = string
    gateway_name_stem = string
    allowed_methods = list(string)
    cached_methods = list(string)
    compress = bool
    ttls = object({
      min = number
      default = number
      max = number
    })
    forwarded_values = object({
      query_string = bool
      query_string_cache_keys = any
      headers = list(string)
    })
    lambda = object({
      arn = string
      name = string
    })
  }))
  default = []
}

locals {
  apigateway_names = distinct([ for origin in var.lambda_origins: origin.gateway_name_stem])
  apigateway_configs = [for gateway in distinct([ for origin in var.lambda_origins: origin.gateway_name_stem]) :
  [ for origin in var.lambda_origins: origin if origin.gateway_name_stem == gateway] ]
}
