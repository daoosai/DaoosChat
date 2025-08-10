FROM ruby:3.4.4 AS builder

# Install system dependencies, Node.js and pnpm
RUN apt-get update -qq && apt-get install -y \
    curl gnupg build-essential libpq-dev git \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && corepack enable \
  && corepack prepare pnpm@10.0.0 --activate

WORKDIR /app

# Copy and install Ruby dependencies
COPY Gemfile* ./
RUN bundle install --without development test

# Copy package manifests first for caching
COPY package.json pnpm-lock.yaml* ./
RUN echo "ignore-engine=true" >> .npmrc && pnpm install --frozen-lockfile

# Copy rest of the app
COPY . .

# Update browserslist and suppress deprecation warnings
RUN npx update-browserslist-db@latest --yes
ENV NODE_OPTIONS="--max-old-space-size=4096 --no-deprecation"

# Install additional dev tools only for build
RUN pnpm add -D sass-embedded vite-plugin-ruby postcss postcss-preset-env autoprefixer \
    @egoist/tailwindcss-icons sass sass-loader @vitejs/plugin-vue @vue/compiler-sfc

# Build main UI and SDK
RUN pnpm vite build --config vite.config.ts --logLevel error \
 && BUILD_MODE=library pnpm vite build --config vite.config.ts --logLevel error

# Precompile Rails assets
RUN mkdir -p log && touch log/development.log \
 && bundle exec rake assets:precompile

# -------------------------------
# Final production image
FROM ruby:3.4.4

WORKDIR /app

# Install minimal runtime dependencies
RUN apt-get update -qq && apt-get install -y libpq-dev git && rm -rf /var/lib/apt/lists/*

# Copy Ruby gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy built app (no dev deps)
COPY --from=builder /app /app

ENV NODE_ENV=production

EXPOSE 3000
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]
