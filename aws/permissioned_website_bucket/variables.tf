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
    events = list(string)
    filter_prefix = string
    filter_suffix = string
  }))
  default = []
}
