// Based on https://github.com/aws-samples/cloudfront-authorization-at-edge/blob/c99f34185384b47cfb2273730dbcd380de492d12/src/lambda-edge/shared/validate-jwt.ts
const { decode, verify } = require("jsonwebtoken")
const jwksClient = require("jwks-rsa")
const { SigningKey, RsaSigningKey } = jwksClient

// jwks client is cached at this scope so it can be reused across Lambda invocations
let jwksRsa

function isRsaSigningKey(key) {
  return (key || {}).rsaPublicKey;
}

async function getSigningKey(jwksUri, kid) {
  // Retrieves the public key that corresponds to the private key with which the token was signed
  if (!jwksRsa) {
    jwksRsa = jwksClient({ cache: true, rateLimit: true, jwksUri});
  }
  return new Promise((resolve, reject) => {
    jwksRsa.getSigningKey(kid, (err, jwk) => {
      err
        ? reject(err)
        : resolve(isRsaSigningKey(jwk) ? jwk.rsaPublicKey : jwk.publicKey)
    })
  });
}

async function validate(
  jwtToken,
  jwksUri,
  issuer,
  audience
) {
  const decodedToken = decode(jwtToken, { complete: true })
  if (!decodedToken) {
    throw new Error("Cannot parse JWT token");
  }

  // The JWT contains a "kid" claim, key id, that tells which key was used to sign the token
  const kid = decodedToken["header"]["kid"];
  const jwk = await getSigningKey(jwksUri, kid);

  // Verify the JWT
  // This either rejects (JWT not valid), or resolves (JWT valid)
  const verificationOptions = {
    audience,
    issuer,
    ignoreExpiration: false,
  };

  // JWT's from Cognito are JSON objects
  return new Promise((resolve, reject) => {
    verify(jwtToken, jwk, verificationOptions, (err, decoded) => {
      err ? reject(err) : resolve(decoded)
    })
  });
}

module.exports = { validate }
