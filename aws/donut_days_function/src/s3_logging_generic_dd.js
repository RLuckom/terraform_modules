const {createTask} = require('donut-days');
const fs = require('fs')
const config = fs.existsSync('./config.js') ? require('./config') : {}
const recordCollectors = fs.existsSync('./recordCollectors.js') ? require('./recordCollectors') : {}
const _ = require('lodash');
const AWS = require('aws-sdk')
const zlib = require('zlib')

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

function createDatedS3Key(prefix, scope, action, requestId, date) {
  date = _.isString(date) ? Date.parse(date) : (date instanceof Date ? date : new Date())
  const year = date.getUTCFullYear()
  const month = date.getUTCMonth() + 1
  const day = date.getUTCDate()
  const hour = date.getUTCHours()
  return `${_.trimEnd(prefix, '/')}${prefix !== "" ? "/" : ""}year=${year}/month=${month}/day=${day}/hour=${hour}/scope=${scope}/action=${action}/${requestId || 'undefined'}.gz`
}

function buildLogger(event, context, callback) {
  const logBucket = process.env.LOG_BUCKET
  if (!logBucket) {
    return {callback}
  }
  const logKey = createDatedS3Key(process.env.LOG_PREFIX, process.env.SCOPE, process.env.ACTION, _.get(context, 'awsRequestId'))
  const logs = []
  function log(arg) {
    if (process.env.DONUT_DAYS_DEBUG === "true" || arg.level === 'ERROR' || arg.level === "WARN") {
      logs.push(JSON.stringify(arg))
    }
  }
  function newCallback(taskErr, taskRes) {
    new AWS.S3().putObject({
      Body: zlib.gzipSync(logs.join("\n")),
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
