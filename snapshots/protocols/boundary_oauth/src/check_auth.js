/*
layers:
  - cognito_utils
tests: ../../spec/src/cognito_functions/check_auth.spec.js
*/
// based on https://github.com/aws-samples/cloudfront-authorization-at-edge/blob/c99f34185384b47cfb2273730dbcd380de492d12/src/lambda-edge/check-auth/index.ts
const stringifyQueryString = require("querystring").stringify
// let for rewire
let shared = require("./shared/shared");

let CONFIG;

const handler = async (event) => {
  if (!CONFIG) {
    CONFIG = shared.getCompleteConfig();
    CONFIG.logger.debug(`Configuration loaded: ${JSON.stringify(CONFIG)}`);
  }
  CONFIG.logger.debug(`Event: ${JSON.stringify(event)}`);
  const request = event.Records[0].cf.request;
  const domainName = request.headers["host"][0].value;
  const requestedUri = `${request.uri}${request.querystring ? "?" + request.querystring : ""}`;
  try {
    const { idToken, refreshToken, nonce, nonceHmac } = shared.extractAndParseCookies(
      request.headers,
    );
    CONFIG.logger.debug(`Extracted cookies:, ${JSON.stringify({
      idToken,
      refreshToken,
      nonce,
      nonceHmac,
    })}`);

    // If there's no ID token in your cookies then you are not signed in yet
    if (!idToken) {
      throw new Error("No ID token present in cookies");
    }

    // If the ID token has expired or expires in less than 10 minutes and there is a refreshToken: refresh tokens
    // This is done by redirecting the user to the refresh endpoint
    // After the tokens are refreshed the user is redirected back here (probably without even noticing this double redirect)
    const { exp } = shared.decodeToken(idToken);
    CONFIG.logger.debug(`ID token exp: ${exp} or ${new Date(exp * 1000).toISOString()}`);
    if (Date.now() / 1000 > (exp - 60 * 10) && refreshToken) {
      CONFIG.logger.info(
        "Will redirect to refresh endpoint for refreshing tokens using refresh token"
      );
      const nonce = shared.generateNonce(CONFIG);
      const response = {
        status: "307",
        statusDescription: "Temporary Redirect",
        headers: {
          location: [
            {
              key: "location",
              value: `https://${domainName}${
                CONFIG.redirectPathAuthRefresh
              }?${stringifyQueryString({ requestedUri, nonce })}`,
            },
          ],
          "set-cookie": [
            {
              key: "set-cookie",
              value: `spa-auth-edge-nonce=${encodeURIComponent(nonce)}; ${
                CONFIG.cookieSettings.nonce
              }`,
            },
            {
              key: "set-cookie",
              value: `spa-auth-edge-nonce-hmac=${encodeURIComponent(
                shared.sign(nonce, CONFIG.nonceSigningSecret, CONFIG.nonceLength)
              )}; ${CONFIG.cookieSettings.nonce}`,
            },
          ],
          ...CONFIG.defaultCloudfrontHeaders,
        },
      };
      CONFIG.logger.debug("Returning response:\n", response);
      return response;
    }

    // Validate the token and if a group is required make sure the token has it.
    // If not throw an Error or MissingRequiredGroupError
    await shared.validateAndCheckIdToken(idToken, CONFIG);

    // Return the request unaltered to allow access to the resource:
    CONFIG.logger.debug(`Returning request: ${JSON.stringify(request)}`);
    return request;
  } catch (err) {
    CONFIG.logger.info(`Will redirect to Cognito for sign-in because: ${err}`);

    // Generate new state which involves a signed nonce
    // This way we can check later whether the sign-in redirect was done by us (it should, to prevent CSRF attacks)
    const nonce = shared.generateNonce(CONFIG);
    const state = {
      nonce,
      nonceHmac: shared.sign(nonce, CONFIG.nonceSigningSecret, CONFIG.nonceLength),
      ...shared.generatePkceVerifier(CONFIG),
    };
    CONFIG.logger.debug(`Using new state ${JSON.stringify(state)}`);

    const loginQueryString = stringifyQueryString({
      redirect_uri: `https://${domainName}${CONFIG.redirectPathSignIn}`,
      response_type: "code",
      client_id: CONFIG.clientId,
      state:
        // Encode the state variable as base64 to avoid a bug in Cognito hosted UI when using multiple identity providers
        // Cognito decodes the URL, causing a malformed link due to the JSON string, and results in an empty 400 response from Cognito.
        shared.urlSafe.stringify(
          Buffer.from(
            JSON.stringify({ nonce: state.nonce, requestedUri })
          ).toString("base64")
        ),
      scope: CONFIG.oauthScopes.join(" "),
      code_challenge_method: "S256",
      code_challenge: state.pkceHash,
    });

    // Return redirect to Cognito Hosted UI for sign-in
    const response = {
      status: "307",
      statusDescription: "Temporary Redirect",
      headers: {
        location: [
          {
            key: "location",
            value: `${CONFIG.authDomain}/oauth2/authorize?${loginQueryString}`,
          },
        ],
        "set-cookie": [
          {
            key: "set-cookie",
            value: `spa-auth-edge-nonce=${encodeURIComponent(state.nonce)}; ${
              CONFIG.cookieSettings.nonce
            }`,
          },
          {
            key: "set-cookie",
            value: `spa-auth-edge-nonce-hmac=${encodeURIComponent(
              state.nonceHmac
            )}; ${CONFIG.cookieSettings.nonce}`,
          },
          {
            key: "set-cookie",
            value: `spa-auth-edge-pkce=${encodeURIComponent(state.pkce)}; ${
              CONFIG.cookieSettings.nonce
            }`,
          },
        ],
        ...CONFIG.defaultCloudfrontHeaders,
      },
    };
    CONFIG.logger.debug(`Returning response: ${JSON.stringify(response)}`);
    console.log('end')
    return response;
  }
};

module.exports = {
  handler
}
