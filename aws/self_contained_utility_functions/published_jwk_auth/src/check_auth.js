/*
layers:
  - cognito_utils
tests: ../../spec/src/cognito_functions/check_auth.spec.js
*/

const _ = require('lodash')
const { flattenedVerify } = require('jose-node-cjs-runtime/jws/flattened/verify')
const { parseJwk } = require('jose-node-cjs-runtime/jwk/parse')
const { FlattenedVerify } = require('jose-node-cjs-runtime/jws/flattened/verify')
const AXIOS = require('axios')
const AWS = require('aws-sdk')
let dynamo = new AWS.DynamoDB({region: '${dynamo_region}'})
const converter = require('aws-sdk').DynamoDB.Converter

function accessDeniedResponse(message) {
  writeLog('Denying Access: ' + message)
  return {
    status: "401",
    statusDescription: message || "Access Denied",
    headers: {},
  }
}

let TIMEOUT_SECS = parseInt("${key_timeout_secs}") || 1

const statusMessages = {
  noAuth: 'No auth header present',
  unparseableAuth: 'Auth string was not base64-encoded JSON',
  noSig: 'No signature',
  badTimestamp: 'Timestamp was not a number',
  futureTimestamp: 'Timestamp was in the future',
  expiredTimestamp: 'Timestamp was too far in the past',
  wrongRecipient: 'Auth was not signed for the correct recipient',
  unrecognizedOrigin: 'origin not found in our connections',
  noSigningKey: 'Could not retrieve signing key within 1s',
  verifyFailed: 'Signature verification failed',
}

let CONNECTIONS = {
  timestamp: 0,
  domains: []
}

let domain = "${domain}"

const log = "${log}" === "true"

function keyLocation(domain) {
  return "https://" + domain + `/.well-known/microburin-social/keys/social-signing-public-key.jwk`
}

async function refreshConnections() {
  const queryStructure = {
    ExpressionAttributeValues: {
      ":v1": {
        S: "${connection_state_connected}"
      }
    }, 
    KeyConditionExpression: "${connection_state_key} = :v1", 
    TableName: "${dynamo_table_name}"
  };
  const items = await new Promise((resolve, reject) => {
    dynamo.query(queryStructure, (e, r) => {
      if (e) {
        return reject(e)
      } else {
        return resolve(r)
      }
    })
  })
  return {
    domains: _.map(items.Items, (i) => {
      return converter.unmarshall(i).domain
    }),
    timestamp: new Date().getTime(),
  }
}

async function getSigningKey(domain) {
  const signingKey = await AXIOS.request({
    method: 'get',
    url: keyLocation(domain),
    timeout: 1000 * TIMEOUT_SECS,
  })
  return signingKey.data
}

function writeLog(s) {
  if (log) {
    console.log(s)
  }
}

async function handler(event) {
  const request = event.Records[0].cf.request;
  const auth = _.get(request, 'headers.authorization[0].value', '').substr(7);
  if (!auth) {
    return accessDeniedResponse(statusMessages.noAuth)
  }
  let parsedAuth
  try {
    parsedAuth = JSON.parse(Buffer.from(auth, 'base64').toString('utf8'))
  } catch(e) {
    return accessDeniedResponse(statusMessages.unparseableAuth)
  }
  const {sig, timestamp, origin, recipient} = parsedAuth
  if (!sig) {
    return accessDeniedResponse(statusMessages.noSig)
  }
  const { signature, payload, protected } = sig
  if (!_.isNumber(timestamp)) {
    return accessDeniedResponse(statusMessages.badTimestamp)
  }
  const now = new Date().getTime()
  if (timestamp > now) {
    return accessDeniedResponse(statusMessages.futureTimestamp)
  }
  if (now - timestamp > 2000) {
    return accessDeniedResponse(statusMessages.expiredTimestamp)
  }
  if (recipient !== domain) {
    return accessDeniedResponse(statusMessages.wrongRecipient)
  }
  const signedString = Buffer.from(JSON.stringify({timestamp, origin,  recipient}), 'utf8').toString('base64').replace(/=*$/g, "")
  if (!_.isNumber(_.get(CONNECTIONS, 'timestamp')) || (now - CONNECTIONS.timestamp > 60000)) {
    try {
      CONNECTIONS = await refreshConnections()
    } catch(e) {
      writeLog("error getting connections")
      writeLog(e)
    }
  }
  if (CONNECTIONS.domains.indexOf(origin) === -1) {
    return accessDeniedResponse(statusMessages.unrecognizedOrigin)
  }
  let signingKey
  try {
    signingKey = await getSigningKey(origin)
  } catch(e) {
    return accessDeniedResponse(statusMessages.noSigningKey)
  }
  const jws = {
    signature,
    payload,
    protected
  }
  try {
    const k = await parseJwk(signingKey, 'EdDSA')
    await flattenedVerify(jws, k, {algorithms: ["EdDSA"]})
  } catch(e) {
    return accessDeniedResponse(statusMessages.verifyFailed)
  }
  writeLog('auth success; returning request')
  return request
}

module.exports = {
  handler
}
