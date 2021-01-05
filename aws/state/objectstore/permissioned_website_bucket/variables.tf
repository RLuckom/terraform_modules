variable "bucket_name" {
  type = string
}

variable "origin_id" {
  type = string
}

variable "allowed_origins" {
  type = list(string)
  default = []
}

variable "lambda_notifications" {
  type = list(object({
    lambda_arn = string
    lambda_name = string
    lambda_role_arn = string
    events = list(string)
    filter_prefix = string
    filter_suffix = string
    permission_type = string
  }))
  default = []
}
