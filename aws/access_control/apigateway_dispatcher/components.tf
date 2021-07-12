resource "random_id" "layer_suffix" {
  byte_length = 8
}

module aws_sdk_layer {
  count = var.aws_sdk_layer.present ? 0 : 1
  source = "github.com/RLuckom/terraform_modules//aws/layers/aws_sdk"
  layer_name = "aws_sdk_${random_id.layer_suffix.b64_url}"
}

locals {
  plugin_api_root = trim(var.plugin_api_root, "/")
  plugin_api_root_regex_safe = replace(local.plugin_api_root, "/", "\\/")
  aws_sdk_layer_config = concat(module.aws_sdk_layer.*.layer_config, [var.aws_sdk_layer])[0]
  apigateway_dispatcher_function = <<EOF
const AWS = require('aws-sdk')
const { parse } = require("cookie")

const pluginNameRegex = /^\/[^/]*\/${local.plugin_api_root_regex_safe}\/([^\/]*)/
const pathRegex = /^\/[^/]*(\/${local.plugin_api_root_regex_safe}\/.*)/

const pluginRoleMap = ${jsonencode(var.plugin_role_map)}
const routeToFunctionNameMap = ${jsonencode(var.route_to_function_name_map)}

function getPluginRole(referer) {
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
  const pluginRole = getPluginRole(event.path)
  if (!pluginRole) {
    const response = {
      statusCode: 403,
      "headers": {
        "Content-Type": "text/plain"
      },
      body: "no role found for plugin"
    };
    return callback(null, response)
  } else {
    const params = {
      IdentityPoolId: '${var.identity_pool_id}',
      Logins: {
        '${var.user_pool_endpoint}': idToken,
      }
    }
    cognitoidentity.getId(params, function(err, data) {
      if (err) {
        const response = {
          statusCode: 500,
          "headers": {
            "Content-Type": "text/plain"
          },
          body: err.toString()
        };
        return callback(response)
      }
      cognitoidentity.getCredentialsForIdentity({
        IdentityId: data.IdentityId,
        CustomRoleArn: pluginRole,
        Logins: params.Logins 
      }, (e, d) => {
        if (e) {
          const response = {
            statusCode: 500,
            "headers": {
              "Content-Type": "text/plain"
            },
            body: e.toString()
          };
          return callback(response)
        }
        const lambda = new AWS.Lambda({
          accessKeyId: d.Credentials.AccessKeyId,
          secretAccessKey: d.Credentials.SecretKey,
          sessionToken: d.Credentials.SessionToken
        })
        lambda.invoke({
          FunctionName: routeToFunctionNameMap[event.path.match(pathRegex)[1]],
          InvocationType: 'RequestResponse',
          Payload: JSON.stringify(event)
        }, (e, r) => {
          if (e) {
            const response = {
              statusCode: 500,
              "headers": {
                "Content-Type": "text/plain"
              },
              body: e.toString()
            };
            return callback(response)
          }
          if (r.errorType || r.errorMessage) {
            const response = {
              statusCode: 500,
              "headers": {
                "Content-Type": "text/plain"
              },
              body: JSON.stringify(r)
            };
            return callback(response)
          }
          return callback(null, JSON.parse(r.Payload))
        })
      });
    });
  }
}

module.exports = {
  handler
}
EOF
}

module apigateway_dispatcher {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  account_id = var.account_id
  unique_suffix = var.unique_suffix
  region = var.region
  timeout_secs = 5
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
