FROM ruby:3.3-alpine3.20
LABEL maintainer="me@jason.camp"

# Create app dir
RUN mkdir /app
ADD Gemfile /app

# Build Deps
RUN apk update
RUN apk add make gcc g++
RUN apk add sqlite sqlite-dev sqlite-libs sqlite-static
RUN apk add mariadb-client mariadb-dev mariadb-embedded-dev mariadb-connector-c
RUN apk add postgresql-dev

WORKDIR /app

# Install some rubygems
RUN bundle install
RUN gem list

# Copy in application
ADD src /app/

CMD [ "/app/controller.rb" ]
