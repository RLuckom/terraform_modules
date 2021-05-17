const { parse } = require("cookie")

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

function handler(event, context, callback) {
  const request = event.Records[0].cf.request;
  const idToken = extractCookiesFromHeaders(request.headers)["ID-TOKEN"];
  request.headers.authorization = [
    {
      key: "Authorization",
      value: idToken
    }
  ]
  callback(null, request)
}

module.exports = {
  handler
}
