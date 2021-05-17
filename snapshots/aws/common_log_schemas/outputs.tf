output "year_month_day_hour_partition_keys" {
  value = [
    {
      name = "year"
      type = "string"
    },
    {
      name = "month"
      type = "string"
    },
    {
      name = "day"
      type = "string"
    },
    {
      name = "hour"
      type = "string"
    },
  ]
}

output "lambda_log_columns" {
  value = [
    {
      name = "level"
      type = "string"
    },
    {
      name = "source"
      type = "string"
    },
    {
      name = "sourceinstance"
      type = "string"
    },
    {
      name = "timestamp"
      type = "string"
    },
    {
      name = "tags"
      type = "array<string>"
    },
    {
      name = "metadata"
      type = "map<string,string>"
    }
  ]
}

output "cloudfront_access_log_columns" {
  value = [
    {
      name = "date"
      type = "date"
    },
    {
      name = "time"
      type = "string"
    },
    {
      name = "location"
      type = "string"
    },
    {
      name = "bytes"
      type = "bigint"
    },
    {
      name = "requestip"
      type = "string"
    },
    {
      name = "method"
      type = "string"
    },
    {
      name = "host"
      type = "string"
    },
    {
      name = "uri"
      type = "string"
    },
    {
      name = "status"
      type = "int"
    },
    {
      name = "referrer"
      type = "string"
    },
    {
      name = "useragent"
      type = "string"
    },
    {
      name = "querystring"
      type = "string"
    },
    {
      name = "cookie"
      type = "string"
    },
    {
      name = "resulttype"
      type = "string"
    },
    {
      name = "requestid"
      type = "string"
    },
    {
      name = "hostheader"
      type = "string"
    },
    {
      name = "requestprotocol"
      type = "string"
    },
    {
      name = "requestbytes"
      type = "bigint"
    },
    {
      name = "timetaken"
      type = "float"
    },
    {
      name = "xforwardedfor"
      type = "string"
    },
    {
      name = "sslprotocol"
      type = "string"
    },
    {
      name = "sslcipher"
      type = "string"
    },
    {
      name = "responseresulttype"
      type = "string"
    },
    {
      name = "httpversion"
      type = "string"
    },
    {
      name = "filestatus"
      type = "string"
    },
    {
      name = "encryptedfields"
      type = "int"
    },
    {
      name = "port"
      type = "int"
    },
    {
      name = "ttfb"
      type = "float"
    },
    {
      name = "detailedresulttype"
      type = "string"
    },
    {
      name = "contenttype"
      type = "string"
    },
    {
      name = "contentlength"
      type = "bigint"
    },
    {
      name = "rangestart"
      type = "bigint"
    },
    {
      name = "rangeend"
      type = "bigint"
    }
  ]
}
