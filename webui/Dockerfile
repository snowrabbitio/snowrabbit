FROM ruby:3.3-alpine
LABEL maintainer="me@jason.camp"

# Create app dir
RUN mkdir /app
ADD Gemfile /app

# Make database directory for sqlite
RUN mkdir -p /var/lib/db

# Install some packages
RUN apk update
RUN apk upgrade --no-cache
RUN apk add make gcc g++
RUN apk add sqlite sqlite-dev sqlite-libs sqlite-static
RUN apk add mariadb-client mariadb-dev mariadb-embedded-dev mariadb-connector-c
RUN apk add postgresql-dev

WORKDIR /app

# Install some rubygems
RUN bundle install

# Copy in application
ADD src /app/

CMD [ "/app/webui.rb" ]
