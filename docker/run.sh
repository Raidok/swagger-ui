#! /bin/sh

set -e
BASE_URL=${BASE_URL:-/}
NGINX_ROOT=/usr/share/nginx/html
INDEX_FILE=$NGINX_ROOT/index.html

node /usr/share/nginx/configurator $INDEX_FILE

replace_in_index () {
  if [ "$1" != "**None**" ]; then
    sed -i "s|/\*||g" $INDEX_FILE
    sed -i "s|\*/||g" $INDEX_FILE
    sed -i "s|$1|$2|g" $INDEX_FILE
  fi
}

replace_or_delete_in_index () {
  if [ -z "$2" ]; then
    sed -i "/$1/d" $INDEX_FILE
  else
    replace_in_index $1 $2
  fi
}

if [ "${BASE_URL}" ]; then
  sed -i "s|location / {|location $BASE_URL {|g" /etc/nginx/nginx.conf
fi

if [[ ! -z $HTTP_AUTH ]]; then
  sed -i "s|location / {|location $BASE_URL {|g" /etc/nginx/nginx.conf
  sed -i "s/#auth_basic/auth_basic/g;" /etc/nginx/nginx.conf
  echo -n $HTTP_AUTH > /etc/nginx/.htpasswd
fi

if [[ ! -z $PROXY_PASS_OPENAPI ]]; then
  sed -i "s|#PROXY_PASS_OPENAPI#|$PROXY_PASS_OPENAPI|g" /etc/nginx/nginx.conf
  sed -i "s/#proxy_pass_openapi //g;" /etc/nginx/nginx.conf
fi

replace_in_index myApiKeyXXXX123456789 $API_KEY

if [[ -f $SWAGGER_JSON ]]; then
  cp -s $SWAGGER_JSON $NGINX_ROOT
  REL_PATH="./$(basename $SWAGGER_JSON)"
  sed -i "s|https://petstore.swagger.io/v2/swagger.json|$REL_PATH|g" $INDEX_FILE
  sed -i "s|http://example.com/api|$REL_PATH|g" $INDEX_FILE
fi

if [[ ! -z $SWAGGER_JSON_URL ]]; then
  sed -i "s|https://petstore.swagger.io/v2/swagger.json|$SWAGGER_JSON_URL|g" $INDEX_FILE
  sed -i "s|http://example.com/api|$SWAGGER_JSON_URL|g" $INDEX_FILE
fi

# replace the PORT that nginx listens on if PORT is supplied
if [[ -n "${PORT}" ]]; then
    sed -i "s|8080|${PORT}|g" /etc/nginx/nginx.conf
fi

find $NGINX_ROOT -type f -regex ".*\.\(html\|js\|css\)" -exec sh -c "gzip < {} > {}.gz" \;

exec nginx -g 'daemon off;'
