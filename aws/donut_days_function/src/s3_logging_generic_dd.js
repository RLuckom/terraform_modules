const {createTask} = require('donut-days');
const fs = require('fs')
const config = fs.existsSync('./config.js') ? require('./config') : {}
const recordCollectors = fs.existsSync('./recordCollectors.js') ? require('./recordCollectors') : {}
const _ = require('lodash');
const asyncLib = require('async')
const AWS = require('aws-sdk')
const zlib = require('zlib')

const s3 = new AWS.S3()
const dyn = new AWS.DynamoDB()

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

function formatTaskErr(taskErr) {
  let error = {
    message: taskErr.toString(),
  }
  if (taskErr.stageName) {
    error.stageName = taskErr.stageName
  }
  if (taskErr.dependencyName) {
    error.dependencyName = taskErr.dependencyName
  }
  if (taskErr.sourceSchema) {
    error.sourceSchema = taskErr.sourceSchema
  }
  if (taskErr.params) {
    error.params = taskErr.params
  }
  if (taskErr.apiError) {
    error.apiError = taskErr.apiError
    error.apiErrorStack = _.get(taskErr, 'apiError.stack')
  }
  return JSON.stringify(error)
}

function buildLogger(event, context, callback) {
  const startTime = new Date().getTime()
  const logBucket = process.env.LOG_BUCKET
  const metricTable = process.env.METRIC_TABLE
  let logFunction = function(arg) {
    if (process.env.DONUT_DAYS_DEBUG === "true" || arg.level === 'ERROR' || arg.level === "WARN" || arg.level === "METRIC") {
      console.log(JSON.stringify(arg))
    }
  }
  const logKey = createDatedS3Key(process.env.LOG_PREFIX, process.env.SCOPE, process.env.ACTION, _.get(context, 'awsRequestId'))
  const logs = []
  function log(arg) {
    if (process.env.DONUT_DAYS_DEBUG === "true" || arg.level === 'ERROR' || arg.level === "WARN" || arg.level === "METRIC") {
      logs.push(JSON.stringify(arg))
    }
  }
  if (logBucket) {
    logFunction = log
  }
  function newCallback(taskErr, taskRes, metrics) {
    let formattedTaskErr = null
    if (taskErr) {
      formattedTaskErr = formatTaskErr(taskErr)
    }
    const parallel = []
    // use the time as the range key. Yes, this means
    // that if things happen simultaneously
    // we lose data. But it's metric data in which
    // we're looking for trends, not forensic
    // debugging data.
    const time = new Date().getTime()
    if (metrics && metricTable) {
      const metricData = {
        functionName: _.get(context, 'functionName'),
        requestId: _.get(context, 'awsRequestId'),
        invokedFunctionArn: _.get(context, 'invokedFunctionArn'),
        approximateDuration: time - startTime,
        time,
        metrics,
      }
      parallel.push(function(parallelCallback) {
        dyn.putItem({
          Item: AWS.DynamoDB.Converter.marshall(metricData),
          TableName: metricTable
        }, parallelCallback)
      })
    }
    if (logs.length && logBucket && logKey) {
      log({level: 'METRIC', metrics})
      parallel.push(function(parallelCallback) {
        s3.putObject({
          Body: zlib.gzipSync(logs.join("\n")),
          Bucket: logBucket,
          Key: logKey,
        }, parallelCallback)
      })
    }
    if (parallel.length) {
      asyncLib.parallel(parallel, (e, r) => {
        if (e) {
          console.log(e)
        }
        callback(formattedTaskErr, taskRes)
      })
      return
    } else {
      callback(formattedTaskErr, taskRes)
    }
  }
  return {
    log: logFunction,
    callback: newCallback
  }
}

const helpers = loadHelpers('helpers')
const dependencyHelpers = loadHelpers('dependencyHelpers')

exports.handler = (event, context, callback) => {
  _.each(_.get(event, 'Records'), (rec) => {
    if (_.get(rec, 's3.object.key')) {
      rec.s3.object.decodedKey = decodeURIComponent(rec.s3.object.key.replace(/\+/g, ' '))
    }
  })
  const logger = buildLogger(event, context, callback)
  const ddConfig = config || {}
  config.expectations = config.expectations || event.expectations || {}
  const ddEvent = event.event || event || {}
  createTask(_.cloneDeep(ddConfig), helpers, dependencyHelpers, recordCollectors, logger.log)(ddEvent, context, logger.callback)
}
