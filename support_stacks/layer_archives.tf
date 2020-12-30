module "layer_bucket" {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_bucket"
  request_payer = "Requester"
  acl = "public-read"
  versioning = [{
    enabled = true
  }]
  bucket = var.layer_bucket_name
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
