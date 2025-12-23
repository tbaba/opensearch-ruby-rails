# syntax=docker/dockerfile:1

FROM ruby:3.2-slim

ENV APP_HOME=/app \
    BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    BUNDLE_APP_CONFIG=/bundle/config \
    PATH="/bundle/bin:${PATH}"

WORKDIR ${APP_HOME}

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential default-libmysqlclient-dev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile* ./
RUN bundle install

COPY . .

EXPOSE 4567

CMD ["bundle", "exec", "rerun", "--dir", "app,config", "--", "rackup", "-o", "0.0.0.0", "-p", "4567", "config.ru"]
