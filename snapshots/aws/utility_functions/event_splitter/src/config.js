const _ = require('lodash')

const notifications = ${notifications}

function compareEvent(event, requested) {
  const action = requested.replace(/^s3:/g, "").replace(/\*$/g, "")
  const hasStar = !!requested.match(/\*$/)
  if (hasStar && _.startsWith(event, action)) {
    return true
  }
  return event === action
}

function getNotifiablesForEvent({bucket, key, eventType, payload}) {
  const jsonPayload = JSON.stringify(payload)
  return _.reduce(notifications, (acc, v) => {
    if (_.find(v.events, (e) => compareEvent(eventType, e))) {
      if (_.startsWith(key, v.filter_prefix) && _.endsWith(key, v.filter_suffix)) {
       acc.functionName.push(v.lambda_name)
       acc.payload.push(jsonPayload)
       acc.invocationType.push("Event")
      }
    }
    return acc
  }, {
    functionName: [],
    invocationType: [],
    payload: []
  })
}

module.exports = {
  stages: {
    tags: {
      index: 0,
      transformers: {
        notifications: {
          helper: getNotifiablesForEvent,
          params: {
            key: {ref: 'event.Records[0].s3.object.decodedKey'},
            bucket: {ref: 'event.Records[0].s3.bucket.name'},
            eventType: {ref: 'event.Records[0].eventName'},
            payload: {ref: 'event'},
          }
        }
      },
      dependencies: {
        invoke: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.lambda.invoke'},
            params: {
              explorandaParams: {
                FunctionName: { ref: 'stage.notifications.functionName'},
                Payload: { ref: 'stage.notifications.payload'},
                InvocationType: { ref: 'stage.notifications.invocationType'},
              }
            }
          },
        }
      },
    },
  },
}
