const { default: generateKeyPair } = require('jose/util/generate_key_pair')
const { default: fromKeyLike } = require('jose/jwk/from_key_like')
const fs = require('fs')

const set1Kid = "id"
const set2Kid = "access"

Promise.all([generateKeyPair('RS256'), generateKeyPair('RS256')]).then(
  ([set1, set2]) => {
    Promise.all([fromKeyLike(set1.publicKey), fromKeyLike(set1.privateKey), fromKeyLike(set2.publicKey), fromKeyLike(set2.privateKey)]).then(
      ([set1PubKey, set1PrivKey, set2PubKey, set2PrivKey]) => {
        const pubKeySet = {
          keys: [
            {...{
              alg: "RSA256",
              kid: set1Kid,
              use: "sig"
            }, ...set1PubKey},
            {...{
              alg: "RSA256",
              kid: set2Kid,
              use: "sig"
            }, ...set2PubKey}
          ]
        }
        const privKeySet = {
          keys: [
            {...{
              alg: "RSA256",
              kid: set1Kid,
              use: "sig"
            }, ...set1PrivKey},
            {...{
              alg: "RSA256",
              kid: set2Kid,
              use: "sig"
            }, ...set2PrivKey}
          ]
        }
        fs.writeFileSync(`${__dirname}/../src/cognito_functions/testPubKeySet.json`, JSON.stringify(pubKeySet, null, 2))
        fs.writeFileSync(`${__dirname}/../src/cognito_functions/testPrivKeySet.json`, JSON.stringify(privKeySet, null, 2))
      }
    )
  }
)
