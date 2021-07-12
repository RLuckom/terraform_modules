variable "route53_zone_name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable "subject_alternative_names" {
  type = list(string)
  default = []
}
