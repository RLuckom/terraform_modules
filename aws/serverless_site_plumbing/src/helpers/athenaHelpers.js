const _ = require('lodash')

function athenaPartitionQuery({athenaDb, athenaTable, objectKey}) {
  const { year, month, day, hour } = parseKeyDate(objectKey)
  return `ALTER TABLE ${athenaDb}.${athenaTable}
          ADD IF NOT EXISTS 
          PARTITION (
            year = '${year}',
            month = '${month}',
            day = '${day}',
            hour = '${hour}' );`
}

function createDatedS3Key(prefix, suffix, date) {
  date = _.isString(date) ? Date.parse(date) : ((date instanceof Date || date.year) ? date : new Date())
  const year = date.year || date.getUTCFullYear()
  const month = date.month || date.getUTCMonth() + 1
  const day = date.day || date.getUTCDate()
  const hour = date.hour || date.getUTCHours()
  return `${_.trimEnd(prefix, '/')}${prefix ? '/' : ''}year=${year}/month=${month}/day=${day}/hour=${hour}/${suffix || 'undefined'}`
}

function parseKeyDate(objectKey) {
  const [ignore, date, uniqId] = objectKey.match(/.*([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2})\.(.*).gz/)
  const year = date.slice(0,4)
  const month = date.slice(5,7)
  const day = date.slice(8,10)
  const hour = date.slice(11,13)
  return {
    year, month, day, hour, uniqId, date
  }
}

module.exports = {
  athenaPartitionQuery,
  createDatedS3Key,
  parseKeyDate
}
