/*
layers:
  - cognito_utils
tests: ../../../spec/src/cognito_functions/shared/shared.spec.js
*/
// based on https://github.com/aws-samples/cloudfront-authorization-at-edge/blob/c99f34185384b47cfb2273730dbcd380de492d12/src/lambda-edge/shared/shared.ts
const { readFileSync } = require("fs")
const { createHmac, createHash, randomBytes } = require("crypto")
const { parse } = require("cookie")
const axios = require("axios")
const { Agent } = require("https")
const fs = require('fs')
const html = fs.readFileSync(`${__dirname}/error_page/template.html`).toString('utf8')
const validateJwt = require("./validate_jwt")
const raphlogger = require('raphlogger')
class MissingRequiredGroupError extends Error {}

function getConfigJson() {
  const config = JSON.parse(fs.readFileSync(`${__dirname}/../config.json`).toString('utf8'))
  config.logger = raphlogger.init(null, {
    source: config.source,
    level: config.logLevel,
    sourceInstance: config.sourceInstance,
    component: config.component,
    asyncOutput: false
  })
  config.pluginNameRegex = new RegExp('^/' + config.pluginRoot + '/([^/]*)')
  return config
}

function getResponseHeaders(event, config) {
  const request = event.Records[0].cf.request;
  let requestPath = ""
  const requestUri = new URL(
    request.uri, 
    `https://${config.protectedDomain}`
  )
  requestPath = requestUri.pathname
  const match = requestPath.match(config.pluginNameRegex)
  if (match) {
    return config.cloudfrontPluginHeaders[match[1]] || config.defaultCloudfrontHeaders
  }
  return config.defaultCloudfrontHeaders
}

function getDefaultCookieSettings() {
	// Defaults can be overridden by the user (CloudFormation Stack parameter) but should be solid enough for most purposes
	return {
		idToken: "Path=/; Secure; HttpOnly; SameSite=Strict",
		accessToken: "Path=/; Secure; HttpOnly; SameSite=Strict",
		refreshToken: "Path=/; Secure; HttpOnly; SameSite=Strict",
		nonce: "Path=/; Secure; HttpOnly; SameSite=Strict",
	};
}

function getCompleteConfig() {
  // TODO interpolate config here
  const config = getConfigJson();

  const cookieSettings = getDefaultCookieSettings();

  // Defaults for nonce and PKCE
  const defaults = {
    secretAllowedCharacters:
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~",
    pkceLength: 43, // Should be between 43 and 128 - per spec
    nonceLength: 16,
    nonceMaxAge:
      (cookieSettings.nonce &&
        parseInt(parse(cookieSettings.nonce.toLowerCase())["max-age"])) ||
      60 * 60 * 24,
  };

  return {
    ...defaults,
    ...config,
    cookieSettings,
  };
}

function extractCookiesFromHeaders(headers) {
  // Cookies are present in the HTTP header "Cookie" that may be present multiple times.
  // This utility function parses occurrences  of that header and splits out all the cookies and their values
  // A simple object is returned that allows easy access by cookie name: e.g. cookies["nonce"]
  if (!headers["cookie"]) {
    return {};
  }
  const cookies = headers["cookie"].reduce(
    (reduced, header) => Object.assign(reduced, parse(header.value)),
    {}
  );
  return cookies;
}

function asCloudFrontHeaders(headers) {
  // Turn a regular key-value object into the explicit format expected by CloudFront
  return Object.entries(headers).reduce(
    (reduced, [key, value]) =>
      Object.assign(reduced, {
        [key.toLowerCase()]: [
          {
            key,
            value,
          },
        ],
      }),
    {}
  );
}

function getElasticsearchCookieNames() {
  return {
    idTokenKey: "ID-TOKEN",
    accessTokenKey: "ACCESS-TOKEN",
    refreshTokenKey: "REFRESH-TOKEN",
    cognitoEnabledKey: "COGNITO-ENABLED",
  };
}

function extractAndParseCookies(
  headers,
) {
  const cookies = extractCookiesFromHeaders(headers);
  if (!cookies) {
    return {};
  }

  let cookieNames;
  cookieNames = getElasticsearchCookieNames();

  return {
    idToken: cookies[cookieNames.idTokenKey],
    accessToken: cookies[cookieNames.accessTokenKey],
    refreshToken: cookies[cookieNames.refreshTokenKey],
    nonce: cookies["spa-auth-edge-nonce"],
    nonceHmac: cookies["spa-auth-edge-nonce-hmac"],
    pkce: cookies["spa-auth-edge-pkce"],
  };
}

const generateCookieHeaders = {
  newTokens: (param) =>
    _generateCookieHeaders({ ...param, event: "newTokens" }),
  signOut: (param) =>
    _generateCookieHeaders({ ...param, event: "signOut" }),
  refreshFailed: (param) =>
    _generateCookieHeaders({ ...param, event: "refreshFailed" }),
};

function _generateCookieHeaders(param) {
  /*
    Generate cookie headers for the following scenario's:
      - new tokens: called from Parse Auth and Refresh Auth lambda, when receiving fresh JWT's from Cognito
      - sign out: called from Sign Out Lambda, when the user visits the sign out URL
      - refresh failed: called from Refresh Auth lambda when the refresh failed (e.g. because the refresh token has expired)

    Note that there are other places besides this helper function where cookies can be set (search codebase for "set-cookie")
    */

  const decodedIdToken = decodeToken(param.tokens.id_token);
  const tokenUserName = decodedIdToken["cognito:username"];

  let cookieNames = getElasticsearchCookieNames();
  let cookies = {};
  Object.assign(cookies, {
    [cookieNames.idTokenKey]: `${param.tokens.id_token}; ${param.cookieSettings.idToken}`,
    [cookieNames.accessTokenKey]: `${
      param.tokens.access_token
    }; ${param.cookieSettings.accessToken}`,
    [cookieNames.refreshTokenKey]: `${
      param.tokens.refresh_token
    }; ${param.cookieSettings.refreshToken}`,
  });

  if (param.event === "signOut") {
    // Expire all cookies
    Object.keys(cookies).forEach(
      (key) => (cookies[key] = expireCookie(cookies[key]))
    );
  } else if (param.event === "refreshFailed") {
    // Expire refresh token (so the browser will not send it in vain again)
    cookies[cookieNames.refreshTokenKey] = expireCookie(
      cookies[cookieNames.refreshTokenKey]
    );
  }

  // Always expire nonce, nonceHmac and pkce - this is valid in all scenario's:
  // * event === 'newTokens' --> you just signed in and used your nonce and pkce successfully, don't need them no more
  // * event === 'refreshFailed' --> you are signed in already, why do you still have a nonce?
  // * event === 'signOut' --> clear ALL cookies anyway
  [
    "spa-auth-edge-nonce",
    "spa-auth-edge-nonce-hmac",
    "spa-auth-edge-pkce",
  ].forEach((key) => {
    cookies[key] = expireCookie();
  });

  // Return cookie object in format of CloudFront headers
  return Object.entries({
    ...param.additionalCookies,
    ...cookies,
  }).map(([k, v]) => ({ key: "set-cookie", value: `${k}=${v}` }));
}

function expireCookie(cookie='') {
  const cookieParts = cookie
    .split(";")
    .map((part) => part.trim())
    .filter((part) => !part.toLowerCase().startsWith("max-age"))
    .filter((part) => !part.toLowerCase().startsWith("expires"));
  const expires = `Expires=${new Date(0).toUTCString()}`;
  const [, ...settings] = cookieParts; // first part is the cookie value, which we'll clear
  return ["", ...settings, expires].join("; ");
}

const AXIOS_INSTANCE = axios.create({
  httpsAgent: new Agent({ keepAlive: true }),
});

function decodeToken(jwt) {
  const tokenBody = jwt.split(".")[1];
  const decodableTokenBody = tokenBody.replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(Buffer.from(decodableTokenBody, "base64").toString());
}

async function httpPostWithRetry(
  url,
  data,
  config,
  logger
) {
  let attempts = 0;
  while (true) {
    ++attempts;
    try {
      return await AXIOS_INSTANCE.post(url, data, config);
    } catch (err) {
      logger.debug(`HTTP POST to ${url} failed (attempt ${attempts}):`);
      logger.debug((err.response && err.response.data) || err);
      if (attempts >= 5) {
        // Try 5 times at most
        logger.error(
          `No success after ${attempts} attempts, seizing further attempts`
        );
        throw err;
      }
      if (attempts >= 2) {
        // After attempting twice immediately, do some exponential backoff with jitter
        logger.debug(
          "Doing exponential backoff with jitter, before attempting HTTP POST again ..."
        );
        await new Promise((resolve) =>
          setTimeout(
            resolve,
            25 * (Math.pow(2, attempts) + Math.random() * attempts)
          )
        );
        logger.debug("Done waiting, will try HTTP POST again now");
      }
    }
  }
}

function createErrorHtml(props) {
  const params = { ...props, region: process.env.AWS_REGION };
  return html.replace(
    /\${([^}]*)}/g,
    (_, v) => params[v] || ""
  );
}

const urlSafe = {
  /*
        Functions to translate base64-encoded strings, so they can be used:
        - in URL's without needing additional encoding
        - in OAuth2 PKCE verifier
        - in cookies (to be on the safe side, as = + / are in fact valid characters in cookies)

        stringify:
            use this on a base64-encoded string to translate = + / into replacement characters

        parse:
            use this on a string that was previously urlSafe.stringify'ed to return it to
            its prior pure-base64 form. Note that trailing = are not added, but NodeJS does not care
    */
  stringify: (b64encodedString) =>
    b64encodedString.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_"),
  parse: (b64encodedString) =>
    b64encodedString.replace(/-/g, "+").replace(/_/g, "/"),
};

function sign(
  stringToSign,
  secret,
  signatureLength
) {
  const digest = createHmac("sha256", secret)
    .update(stringToSign)
    .digest("base64")
    .slice(0, signatureLength);
  const signature = urlSafe.stringify(digest);
  return signature;
}

function timestampInSeconds() {
  return (Date.now() / 1000) | 0;
}

async function validateAndCheckIdToken(
  idToken,
  config
) {
  config.logger.info("Validating JWT ...");
  let idTokenPayload = await validateJwt.validate(
    idToken,
    config.tokenJwksUri,
    config.tokenIssuer,
    config.clientId
  );
  config.logger.info("JWT is valid");

  let cognitoGroups = idTokenPayload["cognito:groups"];
  if (!cognitoGroups) {
    throw new MissingRequiredGroupError("Token does not have any groups");
  }
  if (!config.requiredGroup) {
    throw new MissingRequiredGroupError("Config does not specify required group");
  }

  if (!cognitoGroups.includes(config.requiredGroup)) {
    throw new MissingRequiredGroupError("Token does not have required group");
  }
  config.logger.info("JWT has requiredGroup");
}

function generatePkceVerifier(config, pkce) {
  if (!pkce) {
    pkce = [...new Array(config.pkceLength)]
      .map(() => randomChoiceFromIndexable(config.secretAllowedCharacters))
      .join("");
  }
  const verifier = {
    pkce,
    pkceHash: urlSafe.stringify(
      createHash("sha256").update(pkce, "utf8").digest("base64")
    ),
  };
  config.logger.debug(`Generated PKCE verifier: ${JSON.stringify(verifier)}`);
  return verifier;
}

function generateNonce(config) {
  const randomString = [...new Array(config.nonceLength)]
    .map(() => randomChoiceFromIndexable(config.secretAllowedCharacters))
    .join("");
  const nonce = `${timestampInSeconds()}T${randomString}`;
  config.logger.debug(`Generated new nonce: ${nonce}`);
  return nonce;
}

function randomChoiceFromIndexable(indexable) {
  if (indexable.length > 256) {
    throw new Error(`indexable is too large: ${indexable.length}`);
  }
  const chunks = Math.floor(256 / indexable.length);
  const firstBiassedIndex = indexable.length * chunks;
  let randomNumber
  do {
    randomNumber = randomBytes(1)[0];
  } while (randomNumber >= firstBiassedIndex);
  const index = randomNumber % indexable.length;
  return indexable[index];
}


module.exports = {
  MissingRequiredGroupError,
  timestampInSeconds,
  getResponseHeaders,
  generatePkceVerifier,
  generateNonce,
  randomChoiceFromIndexable,
  validateAndCheckIdToken,
  createErrorHtml,
  httpPostWithRetry,
  decodeToken,
  expireCookie,
  extractAndParseCookies,
  getElasticsearchCookieNames,
  asCloudFrontHeaders,
  getDefaultCookieSettings,
  getCompleteConfig,
  getConfigJson,
  extractCookiesFromHeaders,
  generateCookieHeaders,
  sign,
  urlSafe,
}
