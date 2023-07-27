FROM php:8.2-fpm-alpine  AS base

LABEL MAINTAINER="MD.AL-AMIN" \
      "GitHub Link"="https://github.com/alaminAppnap" \
      "PHP Version"="8.2"

RUN apk update

# Set working directory
WORKDIR /app

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install system dependencies
RUN apk add --no-cache mysql-client msmtp perl wget libzip libpng libjpeg-turbo libwebp freetype icu icu-data-full nginx supervisor

RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install uploadprogress \
    && docker-php-ext-enable uploadprogress \
    && apk del .build-deps $PHPIZE_DEPS \
    && chmod uga+x /usr/local/bin/install-php-extensions && sync \
    && install-php-extensions bcmath \
            curl \
            exif \
            fileinfo \
            gd \
            intl \
            mbstring \
            mcrypt \
            mysqli \
            opcache \
            openssl \
            pdo \
            pdo_mysql \
            redis \
            zip \
    &&  echo -e "\n opcache.enable=1 \n opcache.enable_cli=1 \n opcache.memory_consumption=128 \n opcache.interned_strings_buffer=8 \n opcache.max_accelerated_files=4000 \n opcache.revalidate_freq=60 \n opcache.fast_shutdown=1" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

COPY . /app

# add root to www group
RUN chmod -R ug+w /app/storage

# Copy nginx/php/supervisor configs
RUN cp docker/dev/supervisor.conf /etc/supervisord.conf
RUN cp docker/dev/php.ini /usr/local/etc/php/conf.d/app.ini
RUN cp docker/dev/nginx.conf /etc/nginx/http.d/default.conf

RUN cp .env.example .env

# PHP Error Log Files
RUN mkdir /var/log/php
RUN touch /var/log/php/errors.log && chmod 777 /var/log/php/errors.log

RUN composer install --no-dev -o  -n

FROM node:18-alpine AS node

# Set working directory
WORKDIR /app

# Copy Laravel files
COPY --from=base /app /app

# Install NPM dependencies and build assets
RUN npm install && npm run build

# Stage 4: Final Image
FROM base AS final

# Copy Laravel files from composer and frontend stages
COPY --from=node /app/public /app/public

# Set permissions
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Set environment variables
ENV APP_ENV=production
ENV APP_DEBUG=false

# Optimizing Configuration loading
#RUN php artisan config:cache
# Optimizing Route loading
#RUN php artisan route:cache

#RUN php artisan optimize

RUN rm -rf /app/node_modules

COPY --from=base /app /app

RUN chmod +x /app/docker/dev/run.sh

EXPOSE 80

ENTRYPOINT ["/app/docker/dev/run.sh"]

