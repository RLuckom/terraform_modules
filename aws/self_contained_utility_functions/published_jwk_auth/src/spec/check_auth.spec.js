const _ = require('lodash')
const rewire = require('rewire')
const checkAuth = rewire('../check_auth.js')
const http = require('http');
const { parseJwk } = require('jose-node-cjs-runtime/jwk/parse')
const { FlattenedSign } = require('jose-node-cjs-runtime/jws/flattened/sign')
const { generateKeyPair } = require('jose-node-cjs-runtime/util/generate_key_pair')
const converter = new require('aws-sdk').DynamoDB.Converter

const publicKeyObject = {"kty":"OKP","crv":"Ed25519","x":"wxeatbwWtfGpu8QOUIdP6-3NG5JkurcRHhEfQIFxgck"}
const privateKeyObject = {"kty":"OKP","crv":"Ed25519","x":"wxeatbwWtfGpu8QOUIdP6-3NG5JkurcRHhEfQIFxgck","d":"HmN_oSGvMGjcvbbniIcgc1PfQZBZVBC29MmDb7o9FRc"}

const fakeDynamo = {
  query: function (config, callback) {
    if (queryError) {
      return setTimeout(() => callback(queryError), queryTime)
    } else {
      return setTimeout(() => callback(null, {Items: _.map(connections, (c) => {
        return converter.marshall({
          origin: c
        })
      })}), queryTime)
    }
  }
}

const pubKeyJson = JSON.stringify(publicKeyObject)
let queryError
let connections = []
let queryTime = 0

async function startTestServer() {
  let pubKeyServer
  await new Promise(function(resolve, reject) {
    pubKeyServer = http.createServer((req, res) => {
      const chunks = []
      let body
      req.on('data', (chunk) => {
        chunks.push(chunk)
      })
      req.on('end', () => {
        body = Buffer.concat(chunks).toString()
        if (req.method === "GET" && req.url === `/.well-known/microburin-social/keys/social-signing-public-key.jwk`) {
          res.setHeader('content-type', 'application/jwk+json')
          setTimeout(() => {
            res.end(pubKeyJson, 'utf8')
          }, queryTime)
        }
      })
    });
    pubKeyServer.on('clientError', (err, socket) => {
      socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
    });
    pubKeyServer.listen(8001, (e, r) => {
      if (e) {
        console.log(e)
        reject(e)
      }
      resolve(r)
    });
  })
  function closeServer(cb) {
    let servers = 1
    function end() {
      servers -= 1
      if (!servers) {
        return cb()
      }
    }
    pubKeyServer.close(end)
  }
  return { closeServer }
}

function getEvent(request) {
  return {
    Records: [
      {
        cf: { request }
      }
    ]
  }
}

function authedEvent(authHeaderString) {
  return getEvent({
    headers: {
      authorization: [
        {
          value: authHeaderString
        }
      ]
    }
  })
}

function tokenAuthedEvent(token) {
  return authedEvent(`Bearer ${formatToken(token)}`)
}

function replaceKeyLocation(domain) {
  return "http://" + domain + `/.well-known/microburin-social/keys/social-signing-public-key.jwk`
}

let domain = "${domain}"
let connectionSalt = "${connection_list_salt}"
let connectionPassword = "${connection_list_password}"

async function validSignedTokenAuthEvent({timestamp, origin, recipient}, signingKey) {
  const sig = await new FlattenedSign(new TextEncoder().encode(JSON.stringify({timestamp, origin, recipient}))).setProtectedHeader({alg: 'EdDSA'}).sign(signingKey)
  const ret = {timestamp, origin, recipient, sig}
  return tokenAuthedEvent(ret)
}

function validateAccessDenied(res, message) {
  expect(res.status).toEqual('401')
  expect(res.statusDescription).toEqual(message)
}

function validateRequestPassThrough(res, evt) {
  expect(res).toEqual(evt.Records[0].cf.request)
}

function formatToken({sig, timestamp, origin, recipient}) {
  return Buffer.from(JSON.stringify({sig, timestamp, origin, recipient})).toString('base64')
}

const messages = checkAuth.__get__('statusMessages')

describe("check auth", () => {
  let closeServer, privateKey, otherKey, unsetArray
  beforeEach(async () => {
    const serverControls = await startTestServer()
    closeServer = serverControls.closeServer
    privateKey = await parseJwk(privateKeyObject, 'EdDSA')
    const otherKeys = await generateKeyPair('EdDSA')
    otherKey = otherKeys.privateKey
    unsetArray = [checkAuth.__set__('connectionEndpoint', 'http://localhost:8000')]
    unsetArray.push(checkAuth.__set__('CONNECTIONS', null)) 
    unsetArray.push(checkAuth.__set__('keyLocation', replaceKeyLocation)) 
    unsetArray.push(checkAuth.__set__('dynamo', fakeDynamo)) 
  })

  afterEach((done) => {
    connections = []
    queryTime = 0
    _.each(unsetArray, (f) => f())
    closeServer(done)
  })

  it("rejects a request if there is no auth", (done) => {
    checkAuth.handler(getEvent({})).then((res) => {
      validateAccessDenied(res, messages.noAuth)
      done()
    })
  })

  it("rejects a request if the timestamp is in the future", async () => {
    const future = new Date().getTime() + 10000
    const evt = await validSignedTokenAuthEvent({timestamp: future}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.futureTimestamp)
    })
  })

  it("rejects a request if there is no timestamp", async () => {
    const evt = await validSignedTokenAuthEvent({}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.badTimestamp)
    })
  })

  it("rejects a request if the timestamp is too old", async () => {
    const past = new Date().getTime() - 100000
    const evt = await validSignedTokenAuthEvent({timestamp: past}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.expiredTimestamp)
    })
  })

  it("rejects a request if it is not signed for anyone", async () => {
    const now = new Date().getTime()
    const evt = await validSignedTokenAuthEvent({timestamp: now}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.wrongRecipient)
    })
  })

  it("rejects a request if it is not signed for us", async () => {
    const now = new Date().getTime()
    const evt = await validSignedTokenAuthEvent({recipient: "anyone", timestamp: now}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.wrongRecipient)
    })
  })

  it("rejects a request if it was not signed", async () => {
    const future = new Date().getTime() + 10000
    return checkAuth.handler(tokenAuthedEvent({timestamp: future})).then((res) => {
      validateAccessDenied(res, messages.noSig)
    })
  })

  it("rejects a request if it was not signed by the right key", async () => {
    const safeOrigin = "localhost:8001"
    const now = new Date().getTime()
    connections.push(safeOrigin)
    const evt = await validSignedTokenAuthEvent({origin: safeOrigin, recipient: domain, timestamp: now}, otherKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.verifyFailed)
    })
  })

  it("rejects a request if the sender isn't in our connections list", async () => {
    const now = new Date().getTime()
    const evt = await validSignedTokenAuthEvent({recipient: domain, timestamp: now}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.unrecognizedOrigin)
    })
  })

  it("rejects a request if the key takes longer than 1s to get", async () => {
    const safeOrigin = "localhost:8001"
    const now = new Date().getTime()
    queryTime = 2000
    connections.push(safeOrigin)
    const evt = await validSignedTokenAuthEvent({origin: safeOrigin, recipient: domain, timestamp: now}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.noSigningKey)
    })
  })

  it("rejects a request if the token can't be parsed", async () => {
    const now = new Date().getTime()
    const evt = await validSignedTokenAuthEvent({recipient: domain, timestamp: now}, privateKey)
    evt.Records[0].cf.request.headers['authorization'][0].value += "aea"
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.unparseableAuth)
    })
  })

  it("passes through a request with a valid token", async () => {
    const safeOrigin = "localhost:8001"
    const now = new Date().getTime()
    connections.push(safeOrigin)
    const evt = await validSignedTokenAuthEvent({origin: safeOrigin, recipient: domain, timestamp: now}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateRequestPassThrough(res, evt)
    })
  })

})
