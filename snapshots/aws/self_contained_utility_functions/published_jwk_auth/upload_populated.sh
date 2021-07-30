#!/bin/bash
rendered_index=<<EOF
${rendered_index}
EOF

rendered_index=$(cat <<'END_HEREDOC'
${rendered_index}
END_HEREDOC
)

mkdir -p ./workdir
cp -r ./src/shared ./workdir/
cp -r ./nodejs/node_modules ./workdir/

# check_auth
echo "$rendered_index" > ./workdir/index.js
cd workdir
zip -r check_auth_${version}.zip *
aws s3 cp check_auth_${version}.zip s3://${bucket}/${prefix}
rm check_auth_${version}.zip
rm index.js
rm config.json
cd ..
