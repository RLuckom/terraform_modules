/*
layers:
  - cognito_utils
tests: ../../spec/src/cognito_functions/http_headers.spec.js
*/
// based on https://github.com/aws-samples/cloudfront-authorization-at-edge/blob/c99f34185384b47cfb2273730dbcd380de492d12/src/lambda-edge/http-headers/index.ts
let getConfigJson = require("./shared/shared").getConfigJson
const getResponseHeaders = require("./shared/shared").getResponseHeaders

let CONFIG

const AWS_LAMBDA_FUNCTION_VERSION = process.env.AWS_LAMBDA_FUNCTION_VERSION
async function handler (event) {
  if (!CONFIG) {
    CONFIG = getConfigJson()
    CONFIG.logger.debug("Configuration loaded:", CONFIG)
  }
  CONFIG.logger.debug("Event:", event)
  const response = event.Records[0].cf.response
  Object.assign(response.headers, getResponseHeaders(event, CONFIG))
  Object.assign(response.headers, {"x-function-version": [{
    key: 'x-function-version',
    value: AWS_LAMBDA_FUNCTION_VERSION}]
  })
  CONFIG.logger.debug("Returning response:\n", response)
  return response
}

module.exports = {
  handler
}
