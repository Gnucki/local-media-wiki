FROM php:7.4-apache

VOLUME /var/www

RUN apt-get update && apt-get install -y \
    autoconf \
    build-essential \
    libpng-dev \
    libtool \
    pkg-config \
    libgss3 \
    libgd-dev \
    zlib1g-dev \
    libicu-dev \
    g++ \
    procps \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    libzip-dev \
    jpegoptim \
    optipng \
    pngquant \
    gifsicle \
    vim \
    unzip \
    git \
    curl \
    procps \
    gettext-base \
    mariadb-client-10.5 \
    sqlite3 \
    sendmail \
    && rm -rf /var/lib/apt/lists/*

# Install extensions
RUN apt-get update && apt-get install -y \
    libmagickwand-dev --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install pdo_mysql zip exif pcntl mysqli \
    && docker-php-ext-enable mysqli \
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && pecl install imagick-3.7.0 \
    && docker-php-ext-enable imagick \
    && pecl install apcu-5.1.21 \
    && docker-php-ext-enable apcu \
    && docker-php-ext-configure intl --enable-intl \
    && docker-php-ext-install intl

# Configure apache
COPY config/apache/media-wiki.conf /etc/apache2/sites-available/media-wiki.conf
RUN a2enmod rewrite \
    && sed -i 's:^\(Timeout\) .*$:\1 5000:' /etc/apache2/apache2.conf \
    && sed -i 's:^\(MaxKeepAliveRequests\) .*$:\1 1000:' /etc/apache2/apache2.conf \
    && sed -i 's:^\(KeepAliveTimeout\) .*$:\1 50:' /etc/apache2/apache2.conf \
    && a2dissite 000-default.conf \
    && a2ensite media-wiki.conf \
    && sed -i 's:^\(TraceEnable\) .*$:\1 Off:' /etc/apache2/conf-available/security.conf \
    && sed -i 's:^\(ServerSignature\) .*$:\1 Off:' /etc/apache2/conf-available/security.conf \
    && sed -i 's:^\(ServerTokens\) .*$:\1 Prod:' /etc/apache2/conf-available/security.conf \
    && a2enmod headers
COPY config/apache/security.conf /etc/apache2/conf-available/media-wiki-security.conf
RUN a2enconf media-wiki-security.conf

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=2.2.6

WORKDIR /var/www

# Align working container user to host one.
RUN grep -c ${UID}:${GID} /etc/passwd \
    || (groupadd -g ${GID} www \
    && useradd -l -u ${UID} -ms /bin/bash -g www www)

USER ${UID}:${GID}
