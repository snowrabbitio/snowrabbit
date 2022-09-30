FROM ruby:2.6-alpine3.11
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

# Install some rubygems
RUN gem install sinatra
RUN gem install sqlite3
RUN gem install mysql2
#RUN gem install pg
RUN gem install sequel

WORKDIR /app
CMD /app/master.rb
