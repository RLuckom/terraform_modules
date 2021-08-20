const _ = require('lodash')
const rewire = require('rewire')
const checkAuth = rewire('../check_auth.js')
const http = require('http');
const { parseJwk } = require('jose-node-cjs-runtime/jwk/parse')
const { FlattenedSign } = require('jose-node-cjs-runtime/jws/flattened/sign')
const { generateKeyPair } = require('jose-node-cjs-runtime/util/generate_key_pair')
const converter = new require('aws-sdk').DynamoDB.Converter
const { createHash } = require('crypto');

const publicKeyObject = {
  "kty":"OKP",
  "crv":"Ed25519",
  "x":"wxeatbwWtfGpu8QOUIdP6-3NG5JkurcRHhEfQIFxgck"
}

const privateKeyObject = {
  "kty":"OKP",
  "crv":"Ed25519",
  "x":"wxeatbwWtfGpu8QOUIdP6-3NG5JkurcRHhEfQIFxgck",
  "d":"HmN_oSGvMGjcvbbniIcgc1PfQZBZVBC29MmDb7o9FRc"
}

const fakeDynamo = {
  query: function (config, callback) {
    if (queryError) {
      return setTimeout(() => callback(queryError), queryTime)
    } else {
      return setTimeout(() => callback(null, {Items: _.map(connections, (c) => {
        return converter.marshall({
          domain: c
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

function authedEvent(authHeaderString, body, inputTruncated) {
  const req = {
    headers: {
      authorization: [
        {
          value: authHeaderString
        }
      ]
    }
  }
  if (body || inputTruncated) {
    req.body = {
      data: body,
      inputTruncated
    }
  }
  return getEvent(req)
}

function tokenAuthedEvent(token, body, inputTruncated) {
  return authedEvent(`Bearer ${formatToken(token)}`, body, inputTruncated)
}

function replaceKeyLocation(domain) {
  return "http://" + domain + `/.well-known/microburin-social/keys/social-signing-public-key.jwk`
}

let domain = "${domain}"
let connectionSalt = "${connection_list_salt}"
let connectionPassword = "${connection_list_password}"

async function validSignedTokenAuthEvent({timestamp, origin, body, recipient, inputTruncated, bodySig}, signingKey, options) {
  options = options || {}
  if (body && !bodySig) {
    const hash = createHash('sha256')
    hash.update(body)
    const bodySigPayload = options.bodySigPayload || hash.digest('hex')
    bodySig = await new FlattenedSign(new TextEncoder().encode(bodySigPayload)).setProtectedHeader({alg: 'EdDSA'}).sign(options.bodySigningKey || signingKey)
  }
  const sig = await new FlattenedSign(new TextEncoder().encode(options.sigPayload || JSON.stringify({timestamp, origin, recipient, bodySig: bodySig || null }))).setProtectedHeader({alg: 'EdDSA'}).sign(signingKey)
  const ret = {timestamp, origin, recipient, bodySig: options.noBodySig ? null : bodySig || null, sig}
  return tokenAuthedEvent(ret, body, inputTruncated)
}

function validateAccessDenied(res, message) {
  expect(res.status).toEqual('401')
  expect(res.statusDescription).toEqual(message)
}

function validateRequestPassThrough(res, evt) {
  expect(res).toEqual(evt.Records[0].cf.request)
}

function formatToken({sig, timestamp, origin, recipient, bodySig}) {
  return Buffer.from(JSON.stringify({sig, timestamp, origin, recipient, bodySig: bodySig || null})).toString('base64')
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
    unsetArray.push(checkAuth.__set__('CONNECTIONS', {
      timeout: 0,
      connections: []
    })) 
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
    evt.Records[0].cf.request.headers['authorization'][0].value = 'Bearer foo'
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.unparseableAuth)
    })
  })

  it("rejects a request if the body is truncated", async () => {
    const now = new Date().getTime()
    const evt = await validSignedTokenAuthEvent({recipient: domain, timestamp: now, inputTruncated: true}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.bodyTruncated)
    })
  })

  it("rejects a request if there is a body but no body signature", async () => {
    const now = new Date().getTime()
    const evt = await validSignedTokenAuthEvent({recipient: domain, timestamp: now, body: 'hi'}, privateKey, {noBodySig: true})
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.noBodySig)
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

  it("passes through a request with a body with a valid token", async () => {
    const safeOrigin = "localhost:8001"
    const now = new Date().getTime()
    connections.push(safeOrigin)
    const evt = await validSignedTokenAuthEvent({origin: safeOrigin, recipient: domain, timestamp: now, body: "signme"}, privateKey)
    return checkAuth.handler(evt).then((res) => {
      validateRequestPassThrough(res, evt)
    })
  })

  it("denies a request with a body signed by the wrong key", async () => {
    const safeOrigin = "localhost:8001"
    const now = new Date().getTime()
    connections.push(safeOrigin)
    const evt = await validSignedTokenAuthEvent({origin: safeOrigin, recipient: domain, timestamp: now, body: "signme"}, privateKey, { bodySigningKey: otherKey})
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.verifyBodyFailed)
    })
  })

  it("denies a request with a body signed by the wrong key", async () => {
    const safeOrigin = "localhost:8001"
    const now = new Date().getTime()
    connections.push(safeOrigin)
    const evt = await validSignedTokenAuthEvent({origin: safeOrigin, recipient: domain, timestamp: now, body: "signme"}, privateKey, { sigPayload: 'boo'})
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.incorrectSigPayload)
    })
  })

  it("denies a request with a body signed by the wrong key", async () => {
    const safeOrigin = "localhost:8001"
    const now = new Date().getTime()
    connections.push(safeOrigin)
    const evt = await validSignedTokenAuthEvent({origin: safeOrigin, recipient: domain, timestamp: now, body: "signme"}, privateKey, { bodySigPayload: 'boo'})
    return checkAuth.handler(evt).then((res) => {
      validateAccessDenied(res, messages.incorrectBodySigPayload)
    })
  })

})
