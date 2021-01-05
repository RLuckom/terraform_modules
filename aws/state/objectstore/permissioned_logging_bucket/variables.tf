variable "bucket_name" {
  type = string
}

variable "include_cookies" {
  default = false
}

variable partitioned_data_sink {
  type = list(object({
    filter_prefix = string
    filter_suffix = string
    lambda_arn = string
    lambda_name = string
  }))
  default = []
}
