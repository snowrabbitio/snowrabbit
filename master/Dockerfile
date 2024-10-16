FROM ruby:3.3-alpine
MAINTAINER me@jason.camp

# Copy in application
RUN mkdir /app
ADD src /app/

# Make database directory for sqlite
RUN mkdir -p /var/lib/db

# Install some packages
RUN apk update
RUN apk add make gcc g++
RUN apk add sqlite sqlite-dev sqlite-libs sqlite-static
RUN apk add mariadb-client mariadb-dev mariadb-embedded-dev mariadb-connector-c

WORKDIR /app

# Install some rubygems
RUN bundle install

CMD /app/master.rb
