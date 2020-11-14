variable maxReceiveCount {
  default = 3
}

variable queue_name {
  type = string
}

variable make_dead_letter {
  default = true
}

variable redrive_policy {
  type = list(object({
    deadLetterTargetArn = string
    maxReceiveCount = number
  }))
  default = []
}
