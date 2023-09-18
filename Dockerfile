FROM php:8.2-fpm-alpine3.18
RUN set -ex; \
    \
    export CFLAGS="-Os"; \
    export CPPFLAGS="${CFLAGS}"; \
    export LDFLAGS="-Wl,--strip-all"; \
    \
    # Runtime dependencies
    apk add --no-cache \
        c-client \
        icu \
        libintl \
        libpng \
        libzip \
        msmtp \
        nginx \
        openldap \
        runit \
    ; \
    \
    # Build dependencies
    apk add --no-cache --virtual .build-deps \
        ${PHPIZE_DEPS} \
        gettext-dev \
        icu-dev \
        imap-dev \
        libpng-dev \
        libzip-dev \
        openldap-dev \
    ; \
    \
    # Install PHP extensions
    docker-php-ext-configure imap --with-imap-ssl; \
    docker-php-ext-install -j "$(nproc)" \
        gd \
        gettext \
        imap \
        intl \
        ldap \
        mysqli \
        sockets \
        zip \
    ; \
    pecl install apcu; \
    docker-php-ext-enable \
        apcu \
        opcache \
    ; \
    \
    # Create msmtp log
    touch /var/log/msmtp.log; \
    chown www-data:www-data /var/log/msmtp.log; \
    \
    # Create data dir
    mkdir /var/lib/osticket; \
    \
    # Clean up
    apk del .build-deps; \
    rm -rf /tmp/pear /var/cache/apk/*
# DO NOT FORGET TO CHECK THE LANGUAGE PACK DOWNLOAD URL BELOW
ENV OSTICKET_VERSION=1.17.4 \
    OSTICKET_SHA256SUM=be3ade536a19b875e16fe0d9716e07f3897f5c0cdbd4efe4ff17ab262d98bed3
    # OSTICKET_VERSION=1.17.2 \
    # OSTICKET_SHA256SUM=53aa6349c0ee6367d4370cc663a8047d3038f5e0d3668f42b3f90f20534fb717
    # OSTICKET_VERSION=1.17.1 \
    # OSTICKET_SHA256SUM=0c83bade36906d31680ee47ed3c062052d2671bcdf9823bbeb78eeb33d30f801
    # OSTICKET_VERSION=1.17 \
    # OSTICKET_SHA256SUM=296d55cc50782411f0ba81101bc64fc4f6ac65a37772fd75bb5f4dc04d8b364d
RUN set -ex; \
    \
    wget -q -O osTicket.zip https://github.com/osTicket/osTicket/releases/download/\
v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip; \
    echo "${OSTICKET_SHA256SUM}  osTicket.zip" | sha256sum -c; \
    unzip osTicket.zip 'upload/*'; \
    rm osTicket.zip; \
    mkdir /usr/local/src; \
    mv upload /usr/local/src/osticket; \
    # Hard link the sources to the public directory
    cp -al /usr/local/src/osticket/. /var/www/html; \
    # Remove setup
    rm -r /var/www/html/setup; \
    \
    for lang in ar_EG ar_SA az bg bn bs ca cs da de el es_AR es_ES es_MX et eu fa fi fr gl he hi \
        hr hu id is it ja ka km ko lt lv mk mn ms nl no pl pt_BR pt_PT ro ru sk sl sq sr sr_CS \
        sv_SE sw th tr uk ur_IN ur_PK vi zh_CN zh_TW; do \
        # This URL is the same as what is used by the official osTicket Downloads page. This URL is
        # used even for minor versions >= 14.
        wget -q -O /var/www/html/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/1.14.x/${lang}.phar; \
    done
RUN set -ex; \
    \
    for plugin in audit auth-2fa auth-ldap auth-passthru auth-password-policy storage-fs; do \
        wget -q -O /var/www/html/include/plugins/${plugin}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/plugin/${plugin}.phar; \
    done; \
    for plugin in auth-oauth2 storage-s3; do \
        wget -q -O /var/www/html/include/plugins/${plugin}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/plugin/1.17.x/${plugin}.phar; \
    done
COPY root /
CMD ["start"]
STOPSIGNAL SIGTERM
EXPOSE 80
HEALTHCHECK CMD curl -fIsS http://localhost/ || exit 1