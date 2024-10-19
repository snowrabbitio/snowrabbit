FROM ruby:3.3-alpine
LABEL maintainer="me@jason.camp"

# Create app dir
RUN mkdir /app
ADD Gemfile /app

# Build Deps
RUN apk update
RUN apk add make gcc g++
RUN apk add sqlite sqlite-dev sqlite-libs sqlite-static

WORKDIR /app

# Install some rubygems
RUN bundle install

# Copy in application
ADD src /app/

CMD [ "/app/probe.rb" ]
