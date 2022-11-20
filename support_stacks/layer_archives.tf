data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

module "logging_bucket" {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/logging_bucket"
  name = "rluckom-support-s3-logging"
  account_id = local.account_id
  region = local.region
}

module "layer_bucket" {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  acl = "public-read"
  account_id = local.account_id
  region = local.region
  versioning = [{
    enabled = true
  }]
  bucket_logging_config = {
    target_bucket = module.logging_bucket.bucket.id
    target_prefix = "${var.layer_bucket_name}/"
  }
  name = var.layer_bucket_name
  principal_prefix_object_permissions = [
    {
      permission_type = "read_known_objects"
      prefix = ""
      principals = [
        {
          type = "*"
          identifiers = ["*"]
        }
      ]
    }
  ]
}

module "donut_days" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "donut_days"
  path = "${path.root}/src/aws/layers/donut_days/" 
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/donut_days/layer.zip"
}

module "image_dependencies" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "image_dependencies"
  path = "${path.root}/src/aws/layers/image_dependencies/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/image_dependencies/layer.zip"
}

module "markdown_tools" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "markdown_tools"
  path = "${path.root}/src/aws/layers/markdown_tools/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/markdown_tools/layer.zip"
}

module "nlp" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "nlp"
  path = "${path.root}/src/aws/layers/nlp/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/nlp/layer.zip"
}

module "cognito_utils" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "cognito_utils"
  path = "${path.root}/src/aws/layers/cognito_utils/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/cognito_utils/layer.zip"
}

module "node_jose" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "node_jose"
  path = "${path.root}/src/aws/layers/node_jose/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/node_jose/layer.zip"
}

module "aws_sdk" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "aws_sdk"
  path = "${path.root}/src/aws/layers/aws_sdk/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/aws_sdk/layer.zip"
}

module "csv_parser" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "csv_parser"
  path = "${path.root}/src/aws/layers/csv_parser/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/csv_parser/layer.zip"
}

module "archive_utils" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "archive_utils"
  path = "${path.root}/src/aws/layers/archive_utils/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/archive_utils/layer.zip"
}

module "activitypub_utils" {
  source = "github.com/RLuckom/terraform_modules//aws/s3_archive"
  key = "activitypub_utils"
  path = "${path.root}/src/aws/layers/activitypub_utils/"
  bucket = module.layer_bucket.bucket.id
  output_path = "${path.root}/src/aws/layers/activitypub_utils/layer.zip"
}
