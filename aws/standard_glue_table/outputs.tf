data "aws_caller_identity" "current" {}

output "metadata_bucket" {
  value = length(module.data_storage_bucket) == 1 ? module.data_storage_bucket : []
}

output "table" {
  value = aws_glue_catalog_table.table
}

output "permission_sets" {
  value = {
    create_partition_glue_permissions = [{
      actions   =  [
        "glue:CreatePartition",
        "glue:GetTable",
        "glue:GetDatabase",
        "glue:BatchCreatePartition"
      ]
      resources = [
        var.db.arn,
        aws_glue_catalog_table.table.arn,
        "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog",
        "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog*"
      ]
    }]
  }
}
