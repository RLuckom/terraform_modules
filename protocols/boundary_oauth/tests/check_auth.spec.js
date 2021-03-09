const rewire = require('rewire')
const checkAuth = rewire('../src/check_auth.js')
const { getDefaultConfig, useCustomConfig, clearCustomConfig, getAuthedEventWithNoRefresh, getCounterfeitAuthedEvent, clearJwkCache, getUnauthEvent, getAuthedEvent, getUnparseableAuthEvent, shared, startTestOauthServer, validateRedirectToLogin, validateValidAuthPassthrough, validateRedirectToRefresh } = require('./test_utils')

// If the thing the fn returns looks like a response, it's sent back to the browser
// as a response. If it still looks like a request, it's forwarded to the origin

function clearConfig() {
  clearCustomConfig()
  checkAuth.__set__('CONFIG', null)
}

describe('when check_auth gets a request but the oauth keyserver is unreachable', () => {
  let resetShared

  beforeEach(() => {
    clearJwkCache()
    clearConfig()
    resetShared = checkAuth.__set__("shared", shared)
  })

  afterEach(() => {
    resetShared()
  })

  it('redirects to login even if the token happens to be valid (because it cant tell)', async (done) => {
    const req = await getAuthedEvent()
    checkAuth.handler(req).then((response) => {
      validateRedirectToLogin(req, response, {expectNonce: true})
      done()
    })
  })
})

describe('when check_auth gets a request', () => {
  let resetShared, closeServer

  beforeAll(async (done) => {
    const testServer = await startTestOauthServer()
    closeServer = testServer.closeServer
    done()
  })

  afterAll((done) => {
    closeServer((e, r) => {
      done()
    })
  })
  /* Things used by the handler
   * * Config (complete)
   * * cookie headers 
   *     id token (regexed b64 of jwt)
   *     id token expiration ("exp" of decoded jwt)
   *     id token payload cognito:groups
   * * nonce signing secret, nonce length
   * * config clientId
   * * config issuer
   * * JWKS uri (mock this to return jwks)
   * * JWKS
   * * expected group from config
   */

  describe("and it IS NOT accompanied by a valid token", () => {

    beforeEach(() => {
      clearJwkCache()
      clearConfig()
      resetShared = checkAuth.__set__("shared", shared)
    })

    afterEach(() => {
      resetShared()
    })
    it('redirects to cognito if no token is present', (done) => {
      const req = getUnauthEvent()
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the token is unparseable', async (done) => {
      const req = await getUnparseableAuthEvent()
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the token is correct in all attributes but not signed by the real key with the kid', async (done) => {
      const req = await getCounterfeitAuthedEvent()
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the issuer is wrong', async (done) => {
      const req = await getAuthedEvent("foobarbaz")
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the clientId is wrong', async (done) => {
      const req = await getAuthedEvent(null, "foobarbaz")
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the kid doesnt match a kid presented by the server', async (done) => {
      const req = await getAuthedEvent(null, null, null, null, 'wokka')
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the token doesnt have the required group', async (done) => {
      const req = await getAuthedEvent(null, null, null, null, null, [])
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the token is fine but the config doesnt specify a required group', async (done) => {
      const customConfig = getDefaultConfig()
      delete customConfig.requiredGroup
      useCustomConfig(customConfig)
      const req = await getAuthedEvent()
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to cognito if the token doesnt have any groups', async (done) => {
      const req = await getAuthedEvent(null, null, null, null, null, "nogroup")
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })
  })

  describe("and it IS accompanied by a valid token", () => {

    beforeEach(() => {
      clearJwkCache()
      clearConfig()
      resetShared = checkAuth.__set__("shared", shared)
    })

    afterEach(() => {
      resetShared()
    })
    it('passes the request through to the backend', async (done) => {
      const req = await getAuthedEvent()
      checkAuth.handler(req).then((response) => {
        validateValidAuthPassthrough(req, response)
        done()
      })
    })
  })
  describe("and it IS accompanied by a valid token with an old expiration", () => {

    beforeEach(() => {
      clearJwkCache()
      resetShared = checkAuth.__set__("shared", shared)
    })

    afterEach(() => {
      resetShared()
    })

    it('redirects to refresh if the token is already expired and there IS a refresh token', async (done) => {
      const req = await getAuthedEvent(null, null,Math.floor(Date.now() / 1000 - 60 * 60 * 4), Math.floor(Date.now() / 1000 - 60 * 60 * 3))
      checkAuth.handler(req).then((response) => {
        validateRedirectToRefresh(req, response)
        done()
      })
    })

    it('redirects to refresh if the token is within 10 minutes of being expired and there IS a refresh token', async (done) => {
      const req = await getAuthedEvent(null, null,Math.floor(Date.now() / 1000 - 60 * 20), Math.floor(Date.now() / 1000 + 60 * 3))
      checkAuth.handler(req).then((response) => {
        validateRedirectToRefresh(req, response)
        done()
      })
    })

    it('redirects to login if the token is already expired and there IS NOT a refresh token', async (done) => {
      const req = await getAuthedEventWithNoRefresh(null, null,Math.floor(Date.now() / 1000 - 60 * 60 * 4), Math.floor(Date.now() / 1000 - 60 * 60 * 3))
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })

    it('redirects to login if the token is within 10 minutes of being expired and there IS NOT a refresh token', async (done) => {
      const req = await getAuthedEventWithNoRefresh(null, null,Math.floor(Date.now() / 1000 - 60 * 20), Math.floor(Date.now() / 1000 + 60 * 3))
      checkAuth.handler(req).then((response) => {
        validateRedirectToLogin(req, response, {expectNonce: true})
        done()
      })
    })
  })
})
