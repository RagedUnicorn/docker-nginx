FROM alpine:3.9.2

LABEL com.ragedunicorn.maintainer="Michael Wiesendanger <michael.wiesendanger@gmail.com>"

#                 _
#    ____  ____ _(_)___  _  __
#   / __ \/ __ `/ / __ \| |/_/
#  / / / / /_/ / / / / />  <
# /_/ /_/\__, /_/_/ /_/_/|_|
#       /____/

# software versions
ENV \
  NGINX_VERSION=1.15.8 \
  GCC_VERSION=8.2.0-r2 \
  LIBC_DEV_VERSION=0.7.1-r0 \
  MAKE_VERSION=4.2.1-r2 \
  OPENSSL_DEV_VERSION=1.1.1b-r1 \
  PCRE_DEV_VERSION=8.42-r1 \
  ZLIB_DEV_VERSION=1.2.11-r1 \
  LINUX_HEADERS_VERSION=4.18.13-r1 \
  CURL_VERSION=7.64.0-r1 \
  GNUPG_VERSION=2.2.12-r0 \
  LIBXSLT_DEV_VERSION=1.1.32-r0 \
  GD_DEV_VERSION=2.2.5-r1 \
  GEOIP_DEV=1.6.12-r1

ENV \
  NGINX_USER=nginx \
  NGINX_GROUP=nginx \
  GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
  NGINX_CACHE_DIRECTORY="/var/cache/nginx" \
  NGINX_CONFIG="\
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-file-aio \
  "
# explicitly set user/group IDs
RUN addgroup -S "${NGINX_GROUP}" -g 9999 && adduser -S -G "${NGINX_GROUP}" -u 9999 "${NGINX_USER}"

RUN \
  set -ex; \
  apk add --no-cache --virtual .build-deps \
    gcc="${GCC_VERSION}" \
    libc-dev="${LIBC_DEV_VERSION}" \
    make="${MAKE_VERSION}" \
    openssl-dev="${OPENSSL_DEV_VERSION}" \
    pcre-dev="${PCRE_DEV_VERSION}" \
    zlib-dev="${ZLIB_DEV_VERSION}" \
    linux-headers="${LINUX_HEADERS_VERSION}" \
    curl="${CURL_VERSION}" \
    gnupg="${GNUPG_VERSION}" \
    libxslt-dev="${LIBXSLT_DEV_VERSION}" \
    gd-dev="${GD_DEV_VERSION}" \
    geoip-dev="${GEOIP_DEV}"; \
  curl -fSL https://nginx.org/download/nginx-"${NGINX_VERSION}".tar.gz -o nginx.tar.gz; \
  curl -fSL https://nginx.org/download/nginx-"${NGINX_VERSION}".tar.gz.asc -o nginx.tar.gz.asc; \
  export GNUPGHOME="$(mktemp -d)"; \
  found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key ${GPG_KEYS} from ${server}"; \
    gpg --keyserver "${server}" --keyserver-options timeout=10 --recv-keys "${GPG_KEYS}" && found=yes && break; \
  done; \
  test -z "${found}" && echo >&2 "error: failed to fetch GPG key ${GPG_KEYS}" && exit 1; \
  gpg --verify nginx.tar.gz.asc nginx.tar.gz; \
  rm -rf "$GNUPGHOME" nginx.tar.gz.asc; \
  mkdir -p /usr/src; \
  tar -zxC /usr/src -f nginx.tar.gz; \
  rm nginx.tar.gz; \
  cd /usr/src/nginx-"${NGINX_VERSION}"; \
  ./configure $NGINX_CONFIG --with-debug; \
  make -j$(getconf _NPROCESSORS_ONLN); \
  mv objs/nginx objs/nginx-debug; \
  ./configure $NGINX_CONFIG; \
  make -j$(getconf _NPROCESSORS_ONLN); \
  make install; \
  rm -rf /etc/nginx/html/; \
  mkdir /etc/nginx/conf.d/; \
  mkdir -p /usr/share/nginx/html/; \
  install -m644 html/index.html /usr/share/nginx/html/; \
  install -m644 html/50x.html /usr/share/nginx/html/; \
  install -m755 objs/nginx-debug /usr/sbin/nginx-debug; \
  ln -s ../../usr/lib/nginx/modules /etc/nginx/modules; \
  strip /usr/sbin/nginx*; \
  rm -rf /usr/src/nginx-"${NGINX_VERSION}"; \
  \
  # Bring in gettext so we can get `envsubst`, then throw
  # the rest away. To do this, we need to install `gettext`
  # then move `envsubst` out of the way so `gettext` can
  # be deleted completely, then move `envsubst` back.
  apk add --no-cache --virtual .gettext gettext; \
  mv /usr/bin/envsubst /tmp/; \
  \
  runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )"; \
  apk add --no-cache --virtual .nginx-rundeps $runDeps; \
  apk del .build-deps; \
  apk del .gettext; \
  mv /tmp/envsubst /usr/local/bin/; \
  \
  # Bring in tzdata so users could set the timezones through the environment
  # variables
  apk add --no-cache tzdata; \
  \
  # forward request and error logs to docker log collector
  ln -sf /dev/stdout /var/log/nginx/access.log; \
  ln -sf /dev/stderr /var/log/nginx/error.log

  # add healthcheck script
  COPY docker-healthcheck.sh /

  # add launch script
  COPY docker-entrypoint.sh /

RUN \
  mkdir "${NGINX_CACHE_DIRECTORY}"; \
  chown "${NGINX_USER}":"${NGINX_GROUP}" "${NGINX_CACHE_DIRECTORY}"; \
  chmod 755 docker-entrypoint.sh && \
  chmod 755 /docker-healthcheck.sh

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx.vh.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
