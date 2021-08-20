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
const { createHash } = require('crypto');

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
  verifyBodyFailed: 'Signature verification for body failed',
  bodyTruncated: 'Body was over 40kb; got truncated; could not hash',
  noBodySig: "Body present but no body signature",
  incorrectSigPayload: 'Signature payload did not match auth',
  incorrectBodySigPayload: 'body signature payload did not match body hash',
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
    TableName: "${dynamo_table_name}",
    IndexName: "${dynamo_index_name}",
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
  const {sig, bodySig, timestamp, origin, recipient} = parsedAuth
  const body = _.get(request, 'body.data', "") // will be b64
  if (!sig) {
    return accessDeniedResponse(statusMessages.noSig)
  }
  if (_.get(request, 'body.inputTruncated')) {
    return accessDeniedResponse(statusMessages.bodyTruncated)
  }
  if (body && !bodySig) {
    return accessDeniedResponse(statusMessages.noBodySig)
  }
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
  let signingKey, parsedSigningKey
  try {
    signingKey = await getSigningKey(origin)
    parsedSigningKey = await parseJwk(signingKey, 'EdDSA')
  } catch(e) {
    return accessDeniedResponse(statusMessages.noSigningKey)
  }
  try {
    const signedString = Buffer.from(JSON.stringify({timestamp, origin, recipient, bodySig: bodySig || null}), 'utf8').toString('base64')
    const verifiedRequestSignature = await flattenedVerify(sig, parsedSigningKey, {algorithms: ["EdDSA"]})
    if (verifiedRequestSignature.payload.toString('base64') !== signedString) {
      return accessDeniedResponse(statusMessages.incorrectSigPayload)
    }
  } catch(e) {
    return accessDeniedResponse(statusMessages.verifyFailed)
  }
  if (body) {
    let verifiedBodyKey
    try {
      const hash = createHash('sha256')
      hash.update(body)
      const expectedBodySigPayload = hash.digest('hex')
      const verifiedBodySignature = await flattenedVerify(bodySig, parsedSigningKey, {algorithms: ["EdDSA"]})
      if (verifiedBodySignature.payload.toString('utf8') !== expectedBodySigPayload) {
        return accessDeniedResponse(statusMessages.incorrectBodySigPayload)
      }
    } catch(e) {
      return accessDeniedResponse(statusMessages.verifyBodyFailed)
    }
  }
  writeLog('auth success; returning request')
  return request
}

module.exports = {
  handler
}
