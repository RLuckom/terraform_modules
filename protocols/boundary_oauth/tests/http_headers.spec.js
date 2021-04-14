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
        "request": {
          "uri": "/test",
          "method": "GET",
          "querystring": 'foo=bar',
          "headers": {
            "host": [
              {
                "key": "Host",
                "value": "example.com"
              }
            ],
            "cookie": []
          }
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

const modifyResponseHeaderEventForPlugin = {
  "Records": [
    {
      "cf": {
        "config": {
          "distributionId": "EXAMPLE"
        },
        "request": {
          "uri": "/plugins/blog/index.html",
          "method": "GET",
          "querystring": 'foo=bar',
          "headers": {
            "host": [
              {
                "key": "Host",
                "value": "example.com"
              },
            ],
            "cookie": []
          }
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

const modifyResponseHeaderEventForPluginWithHeaders = {
  "Records": [
    {
      "cf": {
        "config": {
          "distributionId": "EXAMPLE"
        },
        "request": {
          "uri": "/plugins/visibility/index.html",
          "method": "GET",
          "querystring": 'foo=bar',
          "headers": {
            "host": [
              {
                "key": "Host",
                "value": "example.com"
              },
            ],
            "cookie": []
          }
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

  it('sets the headers correctly with a plugin with no special headers', (done) => {
    httpHeaders.handler(modifyResponseHeaderEventForPlugin).then((response) => {
      const config = shared.getCompleteConfig()
      validateCloudfrontHeaders(config.httpHeaders, response)
      done()
    })
  })

  it('sets the headers correctly with a plugin with special headers', (done) => {
    const expectedHeaders = {
      "Content-Security-Policy": "default-src 'self';",
      "Referrer-Policy": "same-origin",
      "Strict-Transport-Security": "max-age=31536000; includeSubdomains; preload",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "X-XSS-Protection": "1; mode=block"
    }
    httpHeaders.handler(modifyResponseHeaderEventForPluginWithHeaders).then((response) => {
      const config = shared.getCompleteConfig()
      console.log(response.headers)
      validateCloudfrontHeaders(expectedHeaders, response)
      done()
    })
  })

})
