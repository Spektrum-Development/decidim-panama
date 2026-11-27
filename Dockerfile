FROM ruby:3.4.13 AS builder

RUN apt-get update && apt-get upgrade -y && apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && apt-get install -y nodejs \
    build-essential \
    libclang-dev \
    postgresql-client \
    libvips libvips-tools \
    p7zip \
    libpq-dev && \
    apt-get clean

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
ENV BUNDLE_PATH=/usr/local/bundle

WORKDIR /code

# Copy package dependencies files only to ensure maximum cache hit
COPY ./package-lock.json /code/package-lock.json
COPY ./package.json /code/package.json
COPY ./packages /code/packages
COPY ./Gemfile /code/Gemfile
COPY ./Gemfile.lock /code/Gemfile.lock

RUN gem install bundler:$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1 | xargs) && \
    bundle config set --deployment true && \
    bundle config set --local without 'development test' && \
    bundle install -j4 --retry 3 && \
    npm install yarn -g && \
    # Remove unneeded gems
    bundle clean --force && \
    # Remove unneeded files from installed gems (cache, *.o, *.c)
    rm -rf /usr/local/bundle/cache && \
    find /usr/local/bundle/ -name "*.c" -delete && \
    find /usr/local/bundle/ -name "*.o" -delete && \
    find /usr/local/bundle/ -name ".git" -exec rm -rf {} + && \
    find /usr/local/bundle/ -name ".github" -exec rm -rf {} + && \
    # Remove additional unneeded decidim files
    find /usr/local/bundle/ -name "spec" -exec rm -rf {} + && \
    find /usr/local/bundle/ -wholename "*/decidim-dev/lib/decidim/dev/assets/*" -exec rm -rf {} +

RUN npm ci

# copy the rest of files
COPY ./app /code/app
COPY ./bin /code/bin
COPY ./config /code/config
COPY ./db /code/db
COPY ./lib /code/lib
COPY ./public/*.* /code/public/
COPY ./config.ru /code/config.ru
COPY ./Rakefile /code/Rakefile
COPY ./postcss.config.js /code/postcss.config.js
COPY ./tsconfig.json /code/tsconfig.json

# Compile assets with Webpacker or Sprockets. Executing "assets:precompile"
# also runs "webpacker:compile".
RUN RAILS_ENV=production \
    SECRET_KEY_BASE=dummy \
    DB_ADAPTER=nulldb \
    bin/rails assets:precompile

RUN SECRET_KEY_BASE=dummy \
    DB_ADAPTER=nulldb \
    RAILS_ENV=production \
    bin/rails decidim_api:generate_docs

RUN rm -rf node_modules packages/*/node_modules tmp/* vendor/bundle test spec app/packs .git

# This image is for production env only
FROM ruby:3.4.13-slim AS final

RUN apt-get update && \
    apt-get install -y postgresql-client \
    libicu76 \
    libvips libvips-tools \
    curl \
    p7zip && \
    apt-get clean

EXPOSE 3000

ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_ENV=production
ENV BUNDLE_PATH=/usr/local/bundle

# Add user
RUN addgroup --system --gid 1000 app && \
    adduser --system --uid 1000 --home /code --group app

WORKDIR /code
COPY ./entrypoint.sh /code/entrypoint.sh
COPY --from=builder --chown=app:app /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder --chown=app:app /code /code
RUN mkdir -p /code/tmp/pids && chown app:app /code/tmp /code/tmp/pids

USER app
HEALTHCHECK --interval=1m --timeout=5s --start-period=30s \
  CMD curl -fsS http://localhost:3000/up || exit 1
ENTRYPOINT ["/code/entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
