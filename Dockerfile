FROM ruby:3.4.4

# Установим системные зависимости, Node.js и Yarn
RUN apt-get update -qq && apt-get install -y \
    curl gnupg build-essential libpq-dev git \
  && curl -fsSL https://deb.nodesource.com/setup_23.x | bash - \
  && apt-get install -y nodejs \
  && corepack enable \
  && corepack prepare yarn@1.22.22 --activate

WORKDIR /app
COPY Gemfile* ./
RUN bundle install

COPY . .

COPY vite.config.ts ./

ENV NODE_ENV=production

RUN rm -f package-lock.json && \
    chown -R root:root /app && \
    chmod -R 755 /app

RUN yarn install --ignore-engines && \
    yarn add -D sass-embedded vite-plugin-ruby postcss postcss-preset-env autoprefixer @egoist/tailwindcss-icons

RUN yarn add -D \
  postcss \
  postcss-preset-env \
  autoprefixer \
  sass \
  sass-loader \
  @vitejs/plugin-vue \
  @vue/compiler-sfc

# Сборка основного UI
RUN yarn vite build --config vite.config.ts

# Затем, опционально, SDK
ENV BUILD_MODE=library
RUN yarn vite build --config vite.config.ts

RUN mkdir -p log && touch log/development.log

RUN bundle exec rake assets:precompile

# Запуск Rails-сервера
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]
