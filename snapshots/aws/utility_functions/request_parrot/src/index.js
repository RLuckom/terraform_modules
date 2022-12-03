const _ = require('lodash')
const AWS = require('aws-sdk')
const needle = require('needle')

const slackCredentialsParameter = process.env.SLACK_CREDENTIAL_PARAM
const slackChannel = process.env.SLACK_CHANNEL
const dyn = new AWS.DynamoDB()
const TTL_SECONDS = 24 * 60 * 60 * _.toNumber(process.env.TTL_DAYS || 90)

function constructReadableError(evt) {
  const responseErrorMessage = _.get(evt, 'responsePayload.errorMessage')
  let ddMetadata = {
    functionArn: _.get(evt, 'requestContext.functionArn'),
    event: evt,
    ttl: _.round(new Date().getTime() / 1000 + TTL_SECONDS)
  }
  try {
    ddMetadata = {...JSON.parse(responseErrorMessage), ...ddMetadata}
  } catch(e) {
  }
  ddMetadata.isoTime = _.get(ddMetadata, 'apiError.time') || _.get(evt, 'requestPayload.eventTime') || new Date().toISOString()
  let ddMetaString = ''
  if (ddMetadata.stageName) {
    ddMetaString += `stageName: ${ddMetadata.stageName}\ndependencyName:${ddMetadata.dependencyName}\nrequestId:${_.get(evt, 'requestContext.requestId')}\n\nstack: ${ddMetadata.apiErrorStack}}`
  }
  const errString = ddMetaString || `Error event sent to slack relay:\n${JSON.stringify(evt)}`
  const message = `Function: ${_.get(evt, 'requestContext.functionArn')}\nCondition: ${_.get(evt, 'requestContext.condition')}\n${errString}`
  return {
    message,
    ddMetadata,
  }
}

function main(event, context, callback) {
  new AWS.SSM().getParameter({
    Name: slackCredentialsParameter,
    WithDecryption: true,
  }, (e, r) => {
    const errorTable = process.env.ERROR_TABLE
    let readableError = {
      message: JSON.stringify(event),
      event,
    }
    const {token} = JSON.parse(r.Parameter.Value)
    const status = _.get(event, 'requestContext.condition')
    if (status !== 'Success') {
      try {
        readableError = constructReadableError(event)
      } catch(e) {
        console.log(e)
      }
    }
    var options = {
      headers: { 'Authorization': `Bearer ${token}` }
    }
    needle.request('POST', 'https://slack.com/api/chat.postMessage', { channel: slackChannel, text: readableError.message }, options, (e, r) => {
      console.log(e)
    })
    dyn.putItem({
      Item: AWS.DynamoDB.Converter.marshall(readableError.ddMetadata),
      TableName: errorTable
    }, (e, r) => {
      console.log(e)
    })
  })
}

module.exports = {
  handler: main
}
