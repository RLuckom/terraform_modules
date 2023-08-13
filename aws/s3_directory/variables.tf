variable bucket_name {
  type = string
}

variable file_configs {
  type = list(object({
    content_type = string
    key = string
    file_path = string
    acl = optional(string)
  }))
  default = []
}

variable unique_suffix {
  type = string
  default = ""
}

resource "aws_s3_object" "assets" {
  count = length(var.file_configs)
  bucket = var.bucket_name
  key    = var.file_configs[count.index].key
  acl = var.file_configs[count.index].acl
  content_type = var.file_configs[count.index].content_type
  source = var.file_configs[count.index].file_path
  etag = filemd5(var.file_configs[count.index].file_path)
}
