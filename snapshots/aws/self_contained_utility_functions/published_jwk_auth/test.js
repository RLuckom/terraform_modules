const fs = require('fs')
const _ = require('lodash')
const { execSync } = require('child_process')
const path = require('path')

const jasminePath = 'tests/support/node_modules/jasmine/bin/jasmine.js'
const nycPath = 'tests/support/node_modules/nyc/bin/nyc.js'
const tests = `${__dirname}/tests/**.spec.js`

const env = {
  NODE_PATH: `${__dirname}/nodejs/node_modules:${__dirname}/tests/support/node_modules/`,
  PATH: process.env.PATH,
}


try {
  console.log(`NODE_PATH=${env.NODE_PATH} ${__dirname}/${nycPath} ${__dirname}/${jasminePath} ${tests}`)
  const result = execSync(`${__dirname}/${nycPath} ${__dirname}/${jasminePath} ${tests}`, {env})
  console.log(result.toString('utf8'))
} catch(e) {
  console.log(e)
  console.log(e.stdout.toString('utf8'))
}
