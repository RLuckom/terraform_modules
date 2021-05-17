/*
layers:
  - cognito_utils
tests: ../../spec/src/cognito_functions/refresh_auth.spec.js
*/
// based on https://raw.githubusercontent.com/aws-samples/cloudfront-authorization-at-edge/c99f34185384b47cfb2273730dbcd380de492d12/src/lambda-edge/refresh-auth/index.ts
const qs = require("querystring")
const stringifyQueryString = qs.stringify
const parseQueryString = qs.parse
let shared = require("./shared/shared");

let CONFIG

const handler = async (event) => {
  if (!CONFIG) {
    CONFIG = shared.getCompleteConfig();
    CONFIG.logger.debug("Configuration loaded:", CONFIG);
  }
  CONFIG.logger.debug("Event:", event);
  const request = event.Records[0].cf.request;
  const domainName = request.headers["host"][0].value;
  let redirectedFromUri = `https://${domainName}`;

  try {
    const { requestedUri, nonce: currentNonce } = parseQueryString(
      request.querystring
    );
    redirectedFromUri += requestedUri || "";
    const {
      idToken,
      accessToken,
      refreshToken,
      nonceHmac,
      nonce: originalNonce,
    } = shared.extractAndParseCookies(
      request.headers,
      CONFIG.clientId,
      CONFIG.cookieCompatibility
    );

    validateRefreshRequest(
      currentNonce,
      originalNonce,
      idToken,
      accessToken,
      refreshToken,
      nonceHmac,
      CONFIG,
    );

    let headers = {
      "Content-Type": "application/x-www-form-urlencoded",
    };

    const encodedSecret = Buffer.from(
      `${CONFIG.clientId}:${CONFIG.clientSecret}`
    ).toString("base64");
    headers["Authorization"] = `Basic ${encodedSecret}`;

    let tokens = {
      id_token: idToken,
      access_token: accessToken,
      refresh_token: refreshToken,
    };
    let cookieHeadersEventType
    try {
      const body = stringifyQueryString({
        grant_type: "refresh_token",
        client_id: CONFIG.clientId,
        refresh_token: refreshToken,
      });
      const res = await shared.httpPostWithRetry(
        `${CONFIG.authDomain}/oauth2/token`,
        body,
        { headers },
        CONFIG.logger
      ).catch((err) => {
        throw new Error(`Failed to refresh tokens: ${err}`);
      });
      tokens.id_token = res.data.id_token;
      tokens.access_token = res.data.access_token;
      cookieHeadersEventType = "newTokens";
    } catch (err) {
      cookieHeadersEventType = "refreshFailed";
    }
    const response = {
      status: "307",
      statusDescription: "Temporary Redirect",
      headers: {
        location: [
          {
            key: "location",
            value: redirectedFromUri,
          },
        ],
        "set-cookie": shared.generateCookieHeaders[cookieHeadersEventType]({
          tokens,
          domainName,
          ...CONFIG,
        }),
        ...CONFIG.defaultCloudfrontHeaders,
      },
    };
    CONFIG.logger.debug("Returning response:\n", response);
    return response;
  } catch (err) {
    const response = {
      body: shared.createErrorHtml({
        title: "Refresh issue",
        message: "We can't refresh your sign-in because of a",
        expandText: "technical problem",
        details: err.toString(),
        linkUri: redirectedFromUri,
        linkText: "Try again",
      }),
      status: "200",
      headers: {
        ...CONFIG.defaultCloudfrontHeaders,
        "content-type": [
          {
            key: "Content-Type",
            value: "text/html; charset=UTF-8",
          },
        ],
      },
    };
    CONFIG.logger.debug("Returning response:\n", response);
    return response;
  }
};

function validateRefreshRequest(
  currentNonce,
  originalNonce,
  idToken,
  accessToken,
  refreshToken,
  nonceHmac,
  config,
) {
  if (!originalNonce) {
    throw new Error(
      "Your browser didn't send the nonce cookie along, but it is required for security (prevent CSRF)."
    );
  } else if (currentNonce !== originalNonce) {
    throw new Error("Nonce mismatch");
  } else if (shared.sign(currentNonce, CONFIG.nonceSigningSecret, CONFIG.nonceLength) !== nonceHmac) {
    throw new Error("Nonce hmac not verifiable");
  } 
  Object.entries({ idToken, accessToken, refreshToken }).forEach(
    ([tokenType, token]) => {
      if (!token) {
        throw new Error(`Missing ${tokenType}`);
      }
    }
  );
}

module.exports = { handler }
