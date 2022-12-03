module "request_parrot" {
  source = "../../permissioned_lambda"
  timeout_secs = var.function_time_limit
  account_id = var.account_id
  region = var.region
  mem_mb = var.function_memory_size
  unique_suffix = var.unique_suffix
  source_contents = [
    {
      file_name = "index.js"
      file_contents = <<EOF
      exports.handler = (event, context, callback) => {
        console.log(JSON.stringify(event))
        callback(null, {
          statusCode: 200, 
          body: JSON.stringify(event)
        })
      }
EOF
    },
  ]
  lambda_details = {
    action_name = var.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
}
