provider "archive" {}

provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  region     = "us-east-1"
  profile    = "default"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.22"
    }
  }
  required_version = ">= 0.13"
  backend "s3" {
    shared_credentials_file = "~/.aws/credentials"
    bucket = "raph"
    key    = "supporting_stacks"
    region = "us-east-1"
    profile    = "default"
  }
}
