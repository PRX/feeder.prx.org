FROM ruby:2.7.5-alpine

LABEL org.prx.app="yes"
LABEL org.prx.spire.publish.ecr="RAILS_APP"

RUN apk -U upgrade && apk add --no-cache \
    tzdata postgresql-dev postgresql-client build-base bash coreutils git nodejs

ENV RAILS_ENV production
ENV APP_HOME /app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
ADD Gemfile ./
ADD Gemfile.lock ./

RUN bundle config set --without 'development test' \
    && bundle install --jobs 10 --retry 10 \
    && rm -rf $GEM_HOME/cache/*

ADD . ./
RUN chown -R nobody:nogroup /app
USER root

ENTRYPOINT ["./bin/application"]
CMD ["web"]
