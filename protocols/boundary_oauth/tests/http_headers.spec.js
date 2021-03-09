const rewire = require('rewire')
const httpHeaders = rewire('../src/http_headers')
const { getConfigJson, validateCloudfrontHeaders, refreshAuthRequest, getAuthDependencies, validateHtmlErrorPage, setTokenRequestValidator, clearTokenRequestValidator, TOKEN_REQUEST_VALIDATORS, validateRedirectToRequested, setParseAuthDependencies, clearParseAuthDependencies, TOKEN_HANDLERS, setTokenHandler, clearTokenHandler, parseAuthRequest, getParseAuthDependencies, getDefaultConfig, useCustomConfig, clearCustomConfig, getAuthedEventWithNoRefresh, getCounterfeitAuthedEvent, clearJwkCache, getUnauthEvent, getAuthedEvent, getUnparseableAuthEvent, shared, startTestOauthServer, validateRedirectToLogin, validateValidAuthPassthrough, validateRedirectToRefresh } = require('./test_utils')

const modifyResponseHeaderEvent = {
  "Records": [
    {
      "cf": {
        "config": {
          "distributionId": "EXAMPLE"
        },
        "response": {
          "status": "200",
          "statusDescription": "OK",
          "headers": {
            "vary": [
              {
                "key": "Vary",
                "value": "*"
              }
            ],
            "last-modified": [
              {
                "key": "Last-Modified",
                "value": "2016-11-25"
              }
            ],
            "x-amz-meta-last-modified": [
              {
                "key": "X-Amz-Meta-Last-Modified",
                "value": "2016-01-01"
              }
            ]
          }
        }
      }
    }
  ]
}

describe('cognito http_headers functions test', () => {
  let resetShared

  beforeEach(() => {
    resetShared = httpHeaders.__set__("getConfigJson", getConfigJson)
  })

  afterEach(() => {
    resetShared()
  })


  it('sets the headers', (done) => {
    httpHeaders.handler(modifyResponseHeaderEvent).then((response) => {
      const config = shared.getCompleteConfig()
      validateCloudfrontHeaders(config.httpHeaders, response)
      done()
    })
  })

  it('caches the config', (done) => {
    httpHeaders.handler(modifyResponseHeaderEvent).then((response) => {
      const config = shared.getCompleteConfig()
      validateCloudfrontHeaders(config.httpHeaders, response)
      done()
    })
  })

})
