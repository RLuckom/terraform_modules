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
  get_access_creds_function = <<EOF
const AWS = require('aws-sdk')
const { parse } = require("cookie")

const pluginNameRegex = /^\/${trim(var.plugin_root, "/")}\/([^\/]*)/

const pluginRoleMap = ${jsonencode(var.plugin_role_map)}

function getPluginRole(referer) {
  const match = referer.match(pluginNameRegex)
  if (match) {
    return pluginRoleMap[match[1]]
  }
}

function handler(event, context, callback) {
  const cognitoidentity = new AWS.CognitoIdentity({region: 'us-east-1'});
  const idToken = parse(event.headers['Cookie'])['ID-TOKEN']
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
    const params = {
      IdentityPoolId: '${var.identity_pool_id}',
      Logins: {
        '${var.user_pool_endpoint}': idToken,
      }
    }
    cognitoidentity.getId(params, function(err, data) {
      if (err) {
        return callback(err)
      }
      cognitoidentity.getCredentialsForIdentity({
        IdentityId: data.IdentityId,
        CustomRoleArn: pluginRole,
        Logins: params.Logins 
      }, (e, d) => {
        if (e) {
          return callback(err)
        }
        const response = {
          statusCode: "200",
          cookies: [],
          "headers": {
            "Content-Type": "application/json"
          },
          body: JSON.stringify(d)
        };
        return callback(null, response)
      })
    });
  }
}

module.exports = {
  handler
}
EOF
}

module get_access_creds {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  account_id = var.account_id
  timeout_secs = 2
  mem_mb = 128
  source_contents = [
    {
      file_name = "index.js"
      file_contents = local.get_access_creds_function
    },
  ]
  lambda_details = {
    action_name = "get_access_creds"
    scope_name = "test"
    policy_statements = []
  }
  layers = [local.aws_sdk_layer_config]
}
