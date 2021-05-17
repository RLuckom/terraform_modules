const rewire = require('rewire')
const refreshAuth = rewire('../src/refresh_auth.js')
const { refreshAuthRequest, getAuthDependencies, validateHtmlErrorPage, setTokenRequestValidator, clearTokenRequestValidator, TOKEN_REQUEST_VALIDATORS, validateRedirectToRequested, setParseAuthDependencies, clearParseAuthDependencies, TOKEN_HANDLERS, setTokenHandler, clearTokenHandler, parseAuthRequest, getParseAuthDependencies, getDefaultConfig, useCustomConfig, clearCustomConfig, getAuthedEventWithNoRefresh, getCounterfeitAuthedEvent, clearJwkCache, getUnauthEvent, getAuthedEvent, getUnparseableAuthEvent, shared, startTestOauthServer, validateRedirectToLogin, validateValidAuthPassthrough, validateRedirectToRefresh } = require('./test_utils')

describe('cognito refresh_auth functions test when the oauth server is down', () => {
  let resetShared

  beforeEach(() => {
    resetShared = refreshAuth.__set__("shared", shared)
  })

  afterEach(() => {
    resetShared()
  })

  it('responds with an error to an unauthed request', (done) => {
    const req = getUnauthEvent()
    refreshAuth.handler(req).then((response) => {
      validateHtmlErrorPage(req, response)
      done()
    })
  })

  it('responds with an error to an authed-but-not-refresh request', async (done) => {
    const req = await getAuthedEvent()
    refreshAuth.handler(req).then((response) => {
      validateHtmlErrorPage(req, response)
      done()
    })
  })

  it('returns an error when the nonces dont match', async (done) => {
    const dependencies = await getAuthDependencies()
    dependencies.cookies["spa-auth-edge-nonce"] += 'oops'
    const { event } = await refreshAuthRequest(dependencies)
    refreshAuth.handler(event).then((response) => {
      validateHtmlErrorPage(event, response)
      done()
    })
  })

  it('returns an error when the nonce doesnt match the hmac', async (done) => {
    const dependencies = await getAuthDependencies()
    dependencies.cookies["spa-auth-edge-nonce-hmac"] += 'oops'
    const { event } = await refreshAuthRequest(dependencies)
    refreshAuth.handler(event).then((response) => {
      validateHtmlErrorPage(event, response)
      done()
    })
  })

})

describe('cognito refresh_auth functions test when the oauth server is up', () => {
  let resetShared, tokens

  function receiveTokens(t) {
    tokens = t
  }

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

  beforeEach(() => {
    resetShared = refreshAuth.__set__("shared", shared)
  })

  afterEach(() => {
    resetShared()
  })

  it('responds with an error to an unauthed request', (done) => {
    const req = getUnauthEvent()
    refreshAuth.handler(req).then((response) => {
      validateHtmlErrorPage(req, response)
      done()
    })
  })

  it('responds with an error to an authed-but-not-refresh request', async (done) => {
    const req = await getAuthedEvent()
    refreshAuth.handler(req).then((response) => {
      validateHtmlErrorPage(req, response)
      done()
    })
  })

  it('redirects to requested when the token is refreshed', async (done) => {
    const dependencies = await getAuthDependencies()
    setTokenHandler(TOKEN_HANDLERS.default, receiveTokens)
    setTokenRequestValidator(TOKEN_REQUEST_VALIDATORS.refresh)
    const { event } = await refreshAuthRequest(dependencies)
    refreshAuth.handler(event).then((response) => {
      validateRedirectToRequested(event, response, tokens, dependencies, {expectTokens: true, expectExpiredNonce: true})
      done()
    })
  })

  it('returns an error when the request is missing one of the tokens', async (done) => {
    const dependencies = await getAuthDependencies()
    delete dependencies.cookies['ACCESS-TOKEN']
    setTokenHandler(TOKEN_HANDLERS.default, receiveTokens)
    setTokenRequestValidator(TOKEN_REQUEST_VALIDATORS.refresh)
    const { event } = await refreshAuthRequest(dependencies)
    refreshAuth.handler(event).then((response) => {
      validateHtmlErrorPage(event, response)
      done()
    })
  })

  it('redirects to requested w/ expired refresh token when the token endpoint responds with an error', async (done) => {
    const dependencies = await getAuthDependencies()
    setTokenHandler(TOKEN_HANDLERS.error, receiveTokens)
    setTokenRequestValidator(TOKEN_REQUEST_VALIDATORS.refresh)
    const { event } = await refreshAuthRequest(dependencies)
    refreshAuth.handler(event).then((response) => {
      validateRedirectToRequested(event, response, null, dependencies, {expectTokens: true, expectExpiredNonce: true, expiredRefresh: true})
      done()
    })
  })
})
