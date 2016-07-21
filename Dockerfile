FROM alpine:3.2

MAINTAINER PRX <sysadmin@prx.org>

RUN apk update && apk --update add ca-certificates ruby ruby-irb ruby-json ruby-rake \
    ruby-bigdecimal ruby-io-console libstdc++ tzdata postgresql-client nodejs \
    linux-headers libc-dev zlib libxml2 libxslt libffi less

ENV TINI_VERSION v0.9.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static /tini
RUN chmod +x /tini

ENV RAILS_ENV production
ENV APP_HOME /app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
ADD Gemfile ./
ADD Gemfile.lock ./

RUN apk --update add --virtual build-dependencies build-base ruby-dev openssl-dev \
    postgresql-dev zlib-dev libxml2-dev libxslt-dev libffi-dev && \
    gem install -N bundler && \
    cd $APP_HOME ; \
    bundle config --global build.nokogiri  "--use-system-libraries" && \
    bundle config --global build.nokogumbo "--use-system-libraries" && \
    bundle config --global build.ffi  "--use-system-libraries" && \
    bundle install --jobs 10 --retry 10 && \
    apk del build-dependencies && \
    (find / -type f -iname \*.apk-new -delete || true) && \
    rm -rf /var/cache/apk/* && \
    rm -rf /usr/lib/ruby/gems/*/cache/* && \
    rm -rf /tmp/* /var/tmp/* && \
    rm -rf ~/.gem

ADD . ./
RUN chown -R nobody:nogroup /app
USER nobody

RUN bundle exec rake assets:precompile

ENTRYPOINT ["/tini", "--", "./bin/application"]
CMD ["web"]
