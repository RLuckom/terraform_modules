module "data_storage_bucket" {
  count = var.external_storage_bucket_id == "" ? 1 : 0
  source = "../permissioned_bucket"
  bucket = var.metadata_bucket_name == "" ? "${var.table_name}.metadata" : var.metadata_bucket_name
}

resource "aws_glue_catalog_table" "table" {
  name          = var.table_name
  database_name = var.db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                 = "TRUE"
    "skip.header.line.count" = var.skip_header_line_count
  }

	dynamic "partition_keys" {
		for_each = var.partition_keys
		content {
			name = partition_keys.value["name"]
			type = partition_keys.value["type"]
		}
	}

  storage_descriptor {
    stored_as_sub_directories = var.stored_as_sub_directories
    input_format = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    location = "s3://${var.external_storage_bucket_id == "" ? module.data_storage_bucket[0].bucket.id : var.external_storage_bucket_id}/${var.partition_prefix}${var.partition_prefix == "" ? "" : "/"}"
    compressed = var.compressed

    ser_de_info  {
     name =  var.ser_de_info.name
     serialization_library = var.ser_de_info.serialization_library
     parameters = var.ser_de_info.parameters
   }

    dynamic "columns" {
      for_each = var.columns
      content {
        name = columns.value["name"]
        type = columns.value["type"]
      }
    }
  }
}
