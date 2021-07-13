#!/bin/bash
full_config='${full_config}'
headers_config='${headers_config}'

mkdir -p ./workdir
cp -r ./src/shared ./workdir/
cp -r ./nodejs/node_modules ./workdir/

# headers
cp ./src/http_headers.js workdir/index.js
echo $headers_config > ./workdir/config.json
cd workdir
zip -r http_headers_${version}.zip *
aws s3 cp http_headers_${version}.zip s3://${bucket}/${prefix}
rm http_headers_${version}.zip
rm index.js
rm config.json
cd ..

# move cookies
cp ./src/move_cookie.js workdir/index.js
cd workdir
zip -r move_cookie_${version}.zip *
aws s3 cp move_cookie_${version}.zip s3://${bucket}/${prefix}
rm move_cookie_${version}.zip
rm index.js
cd ..

# sign_out
cp ./src/sign_out.js workdir/index.js
echo $full_config > ./workdir/config.json
cd workdir
zip -r sign_out_${version}.zip *
aws s3 cp sign_out_${version}.zip s3://${bucket}/${prefix}
rm sign_out_${version}.zip
rm index.js
rm config.json
cd ..

# check_auth
cp ./src/check_auth.js workdir/index.js
echo $full_config > ./workdir/config.json
cd workdir
zip -r check_auth_${version}.zip *
aws s3 cp check_auth_${version}.zip s3://${bucket}/${prefix}
rm check_auth_${version}.zip
rm index.js
rm config.json
cd ..

# refresh_auth
cp ./src/refresh_auth.js workdir/index.js
echo $full_config > ./workdir/config.json
cd workdir
zip -r refresh_auth_${version}.zip *
aws s3 cp refresh_auth_${version}.zip s3://${bucket}/${prefix}
rm refresh_auth_${version}.zip
rm index.js
rm config.json
cd ..

# parse_auth
cp ./src/parse_auth.js workdir/index.js
echo $full_config > ./workdir/config.json
cd workdir
zip -r parse_auth_${version}.zip *
aws s3 cp parse_auth_${version}.zip s3://${bucket}/${prefix}
rm parse_auth_${version}.zip
rm index.js
rm config.json
cd ..
