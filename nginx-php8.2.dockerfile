# Pobranie najnowszego stabilnego wydania Baikal.
FROM alpine AS builder

RUN apk add --no-cache curl jq unzip

RUN set -eu; \
    curl -fsSL --retry 3 \
        https://api.github.com/repos/sabre-io/Baikal/releases/latest \
        -o /tmp/release.json; \
    VERSION="$(jq -er '.tag_name | ltrimstr("v")' /tmp/release.json)"; \
    URL="$(jq -er --arg name "baikal-$VERSION.zip" \
        '.assets[] | select(.name == $name) | .browser_download_url' \
        /tmp/release.json)"; \
    echo "Building Baikal $VERSION"; \
    curl -fSL --retry 3 "$URL" -o /tmp/baikal.zip; \
    unzip -q /tmp/baikal.zip -d /; \
    test -f /baikal/vendor/autoload.php; \
    test -f /baikal/html/dav.php

# Obraz produkcyjny: nginx i PHP 8.2.
FROM nginx:1

RUN set -eu; \
    curl -fsSL --retry 3 \
        https://packages.sury.org/php/apt.gpg \
        -o /etc/apt/trusted.gpg.d/php.gpg; \
    apt-get update; \
    apt-get install -y --no-install-recommends lsb-release; \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/php.list; \
    apt-get remove -y lsb-release; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        php8.2-cli \
        php8.2-curl \
        php8.2-fpm \
        php8.2-mbstring \
        php8.2-mysql \
        php8.2-pgsql \
        php8.2-sqlite3 \
        php8.2-xml \
        sqlite3 \
        msmtp \
        msmtp-mta; \
    rm -rf /var/lib/apt/lists/*; \
    sed -i 's/www-data/nginx/' /etc/php/8.2/fpm/pool.d/www.conf; \
    sed -i 's|^listen = .*|listen = /var/run/php-fpm.sock|' \
        /etc/php/8.2/fpm/pool.d/www.conf

# Oryginalne skrypty uruchomieniowe z repozytorium ckulka.
COPY files/docker-entrypoint.d/*.sh \
     files/docker-entrypoint.d/*.php \
     files/docker-entrypoint.d/nginx/ \
     /docker-entrypoint.d/

# Baikal wraz z zależnościami z oficjalnej paczki wydania.
COPY --from=builder --chown=nginx:nginx \
     /baikal /var/www/baikal

# Sprawdzenie wymagań PHP zadeklarowanych przez zależności.
RUN php8.2 -r 'require "/var/www/baikal/vendor/autoload.php";'

# Oryginalna konfiguracja nginx.
COPY files/nginx.conf /etc/nginx/conf.d/default.conf

# Dotychczasowe lokalizacje konfiguracji i danych.
VOLUME /var/www/baikal/config
VOLUME /var/www/baikal/Specific
