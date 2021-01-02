const {createTask} = require('donut-days');
const fs = require('fs')
const config = fs.existsSync('./config.js') ? require('./config') : {}
const recordCollectors = fs.existsSync('./recordCollectors.js') ? require('./recordCollectors') : {}
const _ = require('lodash');
const AWS = require('aws-sdk')

function loadHelpers(s) {
  const sourcePath = `${__dirname}/${s}`
  let helpers = {}
  if (fs.existsSync(sourcePath) && fs.statSync(sourcePath).isDirectory()) {
    const helperFiles = fs.readdirSync(sourcePath)
    helperFiles.forEach((f) => {
      const name = f.split('.')[0]
      helpers[name] = require(`${sourcePath}/${name}`)
    })
    return helpers
  } else if (fs.existsSync(`./${sourcePath}.js`) && fs.statSync(`./${sourcePath}.js`).isFile()) {
    return require(`./${sourcePath}.js`)
  }
  return helpers
}

function buildLogger(event, context, callback) {
  const logBucket = process.env.LOG_BUCKET
  if (!logBucket) {
    return {callback}
  }
  const logKey = `${_.trimEnd(process.env.LOG_PREFIX, '/') || ''}${process.env.LOG_PREFIX ? '/' : ''}${_.get(context, 'awsRequestId') || 'undefined'}.log`
  const logs = []
  function log(level, message) {
    logs.push(`${new Date()} ${level} ${message} `)
  }
  function newCallback(taskErr, taskRes) {
    new AWS.S3().putObject({
      Body: logs.join("\n"),
      Bucket: logBucket,
      Key: logKey,
    }, (e, r) => {
      if (e) {
        console.log(e)
      }
      callback(taskErr, taskRes)
    })
  }
  return {
    log,
    callback: newCallback
  }
}

const helpers = loadHelpers('helpers')
const dependencyHelpers = loadHelpers('dependencyHelpers')

exports.handler = (event, context, callback) => {
  const logger = buildLogger(event, context, callback)
  const ddConfig = config || {}
  config.expectations = config.expectations || event.expectations || {}
  const ddEvent = event.event || event || {}
  createTask(_.cloneDeep(ddConfig), helpers, dependencyHelpers, recordCollectors, logger.log)(ddEvent, context, logger.callback)
}
