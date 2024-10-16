FROM ruby:3.3-alpine
MAINTAINER me@jason.camp

RUN mkdir /app
ADD src /app/

# Development testing
RUN apk update
RUN apk add make gcc g++
RUN apk add sqlite sqlite-dev sqlite-libs sqlite-static

WORKDIR /app

# Install some rubygems
RUN bundle install

RUN gem install sinatra
RUN gem install sqlite3
RUN gem install net-ping
RUN gem install mixlib-shellout

CMD /app/probe.rb
