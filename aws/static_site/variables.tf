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
