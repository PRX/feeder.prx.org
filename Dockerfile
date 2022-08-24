FROM ruby:2.3-alpine3.8

LABEL org.prx.app="yes"
LABEL org.prx.spire.publish.ecr="RAILS_APP"

# install git, aws-cli
RUN apk --no-cache add \
    ca-certificates \
    git \
    groff \
    less \
    libxml2 \
    libxslt \
    linux-headers \
    nodejs \
    postgresql-client \
    python py-pip py-setuptools \
    tzdata \
    sqlite \
    && pip --no-cache-dir install awscli

# install PRX aws-secrets scripts
RUN git clone -o github https://github.com/PRX/aws-secrets
RUN cp ./aws-secrets/bin/* /usr/local/bin

ENV RAILS_ENV production
ENV APP_HOME /app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
ADD Gemfile ./
ADD Gemfile.lock ./

RUN apk --update add --virtual build-dependencies \
    build-base \
    curl-dev \
    libressl-dev \
    postgresql-dev \
    sqlite-dev \
    zlib-dev \
    libxml2-dev \
    libxslt-dev \
    libffi-dev \
    libgcrypt-dev && \
    cd $APP_HOME && \
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

ENTRYPOINT ["./bin/application"]
CMD ["web"]
