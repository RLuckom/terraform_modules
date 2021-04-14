/*
layers:
  - cognito_utils
tests: ../../spec/src/cognito_functions/sign_out.spec.js
*/
// based on https://raw.githubusercontent.com/aws-samples/cloudfront-authorization-at-edge/c99f34185384b47cfb2273730dbcd380de492d12/src/lambda-edge/sign-out/index.ts
const stringifyQueryString = require("querystring").stringify
let shared = require("./shared/shared");

let CONFIG;

const handler = async (event) => {
  if (!CONFIG) {
    CONFIG = shared.getCompleteConfig();
    CONFIG.logger.debug("Configuration loaded:", CONFIG);
  }
  CONFIG.logger.debug("Event:", event);
  const request = event.Records[0].cf.request;
  const domainName = request.headers["host"][0].value;
  const { idToken, accessToken, refreshToken } = shared.extractAndParseCookies(
    request.headers,
    CONFIG.clientId,
    CONFIG.cookieCompatibility
  );

  if (!idToken) {
    const response = {
      body: shared.createErrorHtml({
        title: "Signed out",
        message: "You are already signed out",
        linkUri: `https://${domainName}${CONFIG.redirectPathSignOut}`,
        linkText: "Proceed",
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

  let tokens = {
    id_token: idToken,
    access_token: accessToken,
    refresh_token: refreshToken,
  };
  const qs = {
    logout_uri: `https://${domainName}${CONFIG.redirectPathSignOut}`,
    client_id: CONFIG.clientId,
  };

  const response = {
    status: "307",
    statusDescription: "Temporary Redirect",
    headers: {
      location: [
        {
          key: "location",
          value: `${
            CONFIG.authDomain
          }/logout?${stringifyQueryString(qs)}`,
        },
      ],
      "set-cookie": shared.generateCookieHeaders.signOut({
        tokens,
        domainName,
        ...CONFIG,
      }),
      ...CONFIG.defaultCloudfrontHeaders,
    },
  };
  CONFIG.logger.debug("Returning response:\n", response);
  return response;
};

module.exports = { handler }
