FROM php:7.3-apache-buster as builder


# The version and repository to clone koel from.
ARG KOEL_CLONE_SOURCE=https://github.com/phanan/koel.git
ARG KOEL_VERSION_REF=v4.2.2

# The version of php-composer to install.
ARG COMPOSER_VERSION=1.1.2

# The version of nodejs to install.
ARG NODE_VERSION=node_8.x

# Install dependencies to install dependencies.
RUN apt-get update

RUN rm /etc/apt/preferences.d/no-debian-php

# These are dependencies needed both at build time and at runtime.
ARG RUNTIME_DEPS="\
  libxml2-dev \
  zlib1g-dev \
  libcurl4-openssl-dev \
  libpng-dev \
  composer \
  php-zip \
  php-mbstring \
  php-curl \
  php-xml \
  php-exif"

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes \
  yarnpkg \
  nodejs \
  git \
  ${RUNTIME_DEPS}

# Change to a restricted user.
USER www-data

# Clone the koel repository.
RUN git clone --recurse-submodules ${KOEL_CLONE_SOURCE} -b ${KOEL_VERSION_REF} /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# Install runtime dependencies.
RUN composer install
USER 0

# Debian insists that yarnpkg is the name of the command
RUN yarnpkg install

# The runtime image.
FROM php:7.3-apache-buster

# These are dependencies needed both at build time and at runtime. This is
# repeated because docker doesn't seem to have a way to share args across build
# contexts.
ARG RUNTIME_DEPS="\
  libcurl4-openssl-dev \
  zlib1g-dev \
  libxml2-dev \
  faad \
  ffmpeg \
  composer \
  php-curl \
  php-xml \
  php-zip \
  php-pdo \
  php-mysql \
  php-exif"

# Clean up
RUN rm /etc/apt/preferences.d/no-debian-php

RUN apt-get update && apt-get install --yes \
  gnupg2 \
  apt-transport-https \
  nodejs


RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
&& apt update && apt install --yes --no-install-recommends yarn

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes ${RUNTIME_DEPS} && \
  apt-get clean

# Copy artifacts from build stage.
COPY --from=builder /tmp/koel /var/www/html

# Remove configuration file. All configuration should be passed in as
# environment variables or a bind mounted file at runtime.
RUN rm -f /var/www/html/.env

# Koel makes use of Larvel's pretty URLs. This requires some additional
# configuration: https://laravel.com/docs/4.2#pretty-urls
COPY ./.htaccess /var/www/html

# Fix permissions.
RUN chown -R www-data:www-data /var/www/html
RUN a2enmod rewrite

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD ["apache2-foreground"]

EXPOSE 80
