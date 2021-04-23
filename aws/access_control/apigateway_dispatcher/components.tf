resource "random_id" "layer_suffix" {
  byte_length = 8
}

module aws_sdk_layer {
  count = var.aws_sdk_layer.present ? 0 : 1
  source = "github.com/RLuckom/terraform_modules//aws/layers/aws_sdk"
  layer_name = "aws_sdk_${random_id.layer_suffix.b64_url}"
}

locals {
  aws_sdk_layer_config = concat(module.aws_sdk_layer.*.layer_config, [var.aws_sdk_layer])[0]
  apigateway_dispatcher_function = <<EOF
const AWS = require('aws-sdk')
const { parse } = require("cookie")

const pluginNameRegex = /^\/${trim(var.plugin_root, "/")}\/([^\/]*)/

const pluginRoleMap = ${jsonencode(var.plugin_role_map)}
const routeToFunctionNameMap = ${jsonencode(var.route_to_function_name_map)}

function getPluginRole(referer) {
  const match = referer.match(pluginNameRegex)
  if (match) {
    return pluginRoleMap[match[1]]
  }
}

function getIntendedFunctionName(route) {
  const match = referer.match(pluginNameRegex)
  if (match) {
    return pluginRoleMap[match[1]]
  }
}

function handler(event, context, callback) {
  const cognitoidentity = new AWS.CognitoIdentity({region: 'us-east-1'});
  const idToken = parse(event.headers['Cookie'])['ID-TOKEN']
  delete event.headers['Cookie']
  delete event.headers['cookie']
  const pluginRole = getPluginRole(new URL(event.headers['referer']).pathname)
  if (!pluginRole) {
    const response = {
      statusCode: "403",
      "headers": {
        "Content-Type": "text/plain"
      },
      body: "no role found for plugin"
    };
    return callback(null, response)
  } else {
    const lambda = new AWS.Lambda({
      credentials: new AWS.CognitoIdentityCredentials({
        IdentityPoolId: '${var.identity_pool_id}',
        RoleArn: pluginRole,
        Logins: {
          '${var.user_pool_endpoint}': idToken,
        },
      })
    })
    lambda.invoke({
      FunctionName: routeToFunctionNameMap[event.path],
      InvocationType: 'RequestResponse',
      Payload: JSON.stringify(event)
    }, callback)
  }
}

module.exports = {
  handler
}
EOF
}

module apigateway_dispatcher {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  timeout_secs = 2
  mem_mb = 128
  source_contents = [
    {
      file_name = "index.js"
      file_contents = local.apigateway_dispatcher_function
    },
  ]
  lambda_details = {
    action_name = "apigateway_dispatcher"
    scope_name = "test"
    policy_statements = []
  }
  layers = [local.aws_sdk_layer_config]
}
