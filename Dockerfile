FROM alpine:edge AS builder
LABEL maintainer Naba Das <hello@get-deck.com>
ARG BUILD_DATE
ARG VCS_REF

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/deck-app/nginx-stack.git" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="2.0" \
      org.label-schema.vendor="PHP" \
      org.label-schema.name="docker-php" \
      org.label-schema.description="Docker For PHP Developers - Docker image with PHP 8.1.2, Nginx, and Alpine" \
      org.label-schema.url="https://github.com/deck-app/nginx-stack"

# PHP_INI_DIR to be symmetrical with official php docker image
ENV PHP_INI_DIR /etc/php81

# When using Composer, disable the warning about running commands as root/super user
ENV COMPOSER_ALLOW_SUPERUSER=1

# Persistent runtime dependencies
ARG DEPS="\
        nginx \
        nginx-mod-http-headers-more \
        php81 \
        php81-fpm \
        curl \
        ca-certificates \
        runit \
        php81-phar \
        php81-bcmath \
        php81-calendar \
        php81-mbstring \
        php81-exif \
        php81-ftp \
        php81-openssl \
        php81-zip \
        php81-sysvsem \
        php81-sysvshm \
        php81-sysvmsg \
        php81-shmop \
        php81-sockets \
        php81-zlib \
        php81-bz2 \
        php81-curl \
        php81-simplexml \
        php81-xml \
        php81-opcache \
        php81-dom \
        php81-xmlreader \
        php81-xmlwriter \
        php81-tokenizer \
        php81-ctype \
        php81-session \
        php81-fileinfo \
        php81-iconv \
        php81-mysqli \
        php81-json \
        php81-posix \
        php81-pdo \
        php81-dev \
        php81-pear \
        php81-dom \
        php81-fileinfo \
"

RUN set -x \
    && echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories \
    && apk add --no-cache $DEPS \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx /

COPY default.conf /etc/nginx/http.d/default.conf
ARG SERVER_ROOT

RUN sed -i "s#{SERVER_ROOT}#$SERVER_ROOT#g" /etc/nginx/http.d/default.conf
# VOLUME [ "/var/www/" ]
WORKDIR /var/www

COPY php_ini/php.ini /etc/php81/php.ini

ARG DISPLAY_PHPERROR
RUN if [ ${DISPLAY_PHPERROR} = true ]; then \
sed -i "s#{DISPLAY}#On#g" /etc/php81/php.ini \
;else \
sed -i "s#{DISPLAY}#Off#g" /etc/php81/php.ini \
;fi

RUN ln -s /usr/bin/php81 /usr/bin/php

# mongodb installation
# RUN ln -s /usr/bin/phar81 /usr/bin/phar
RUN apk add --no-cache gdbm libsasl snappy gcc make g++ zlib-dev php81-zip zip unzip php81-pecl-mongodb openssl openssl-dev curl openrc nano bash icu-libs p7zip
# RUN apk add --no-cache php81-pecl-mongodb openssl openssl-dev curl openrc nano bash icu-libs p7zip
RUN apk upgrade

# Composer install
# RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
#      php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
#      php composer-setup.php && \
#      php -r "unlink('composer-setup.php');" && \
#      mv composer.phar /usr/local/bin/composer;
# RUN apk add --no-cache composer
# RUN composer self-update
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

FROM scratch
COPY --from=builder / /

EXPOSE 80
RUN chmod +x /sbin/runit-wrapper
RUN chmod +x /sbin/runsvdir-start
RUN chmod +x /etc/service/nginx/run
RUN chmod +x /etc/service/php-fpm/run

CMD ["/sbin/runit-wrapper"]