FROM ruby:2.7-alpine3.11
MAINTAINER me@jason.camp

RUN mkdir /app
ADD src /app/

# Development testing
RUN apk update
RUN apk add make gcc g++
RUN apk add sqlite sqlite-dev sqlite-libs sqlite-static
#RUN apk add traceroute

RUN gem install sinatra
RUN gem install sqlite3
RUN gem install net-ping
RUN gem install mixlib-shellout

WORKDIR /app
CMD /app/probe.rb
