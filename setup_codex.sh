#!/usr/bin/env bash
set -euo pipefail            # жёсткий режим
IFS=$'\n\t'

##### 0. Переменные окружения #####
export RAILS_ENV=production
export NODE_ENV=production
export INSTALLATION_ENV=codex      # отличим от docker
export DATABASE_URL=postgres://postgres:supersecure123@localhost:5432/chatwoot
export REDIS_URL=redis://:redispass123@localhost:6379
export SECRET_KEY_BASE=11860b3dd8e707e0c25f8fb5cd9ada771e9b437b17b0a4492bba36850cbfe71451d0451d264122830e831f55706bbd4352cb18b6e7dddba0cf61c7b63cc5d2de
export FRONTEND_URL=https://chat.daoos.ai

##### 1. Системные пакеты #####
sudo apt-get update -y
sudo apt-get install -y \
  build-essential git curl gnupg \
  libpq-dev pkg-config \
  redis-server \
  postgresql-16 postgresql-client-16 postgresql-server-dev-16

# ─ pgvector ───────────────────────────────────────────
if ! psql -V | grep -q " 16"; then
  echo "PostgreSQL 16 не найден"; exit 1
fi
# Скомпилируем pgvector из исходников (если пакет postgresql-16-pgvector не
# доступен в репозитории)
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'vector'" | grep -q 1; then
  git clone --depth 1 https://github.com/pgvector/pgvector.git /tmp/pgvector
  pushd /tmp/pgvector
  make
  sudo make install
  popd
fi

##### 2. Настройка PostgreSQL #####
sudo service postgresql start
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'supersecure123';" || true
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'chatwoot'" | grep -q 1 || \
  sudo -u postgres createdb chatwoot
sudo -u postgres psql -d chatwoot -c "CREATE EXTENSION IF NOT EXISTS vector;"

##### 3. Настройка Redis (пароль) #####
sudo sed -i "s/^# *requirepass .*$/requirepass redispass123/" /etc/redis/redis.conf
sudo service redis-server restart

##### 4. Ruby / Node deps #####
# Ruby 3.4 уже есть (см. лог Codex). Установим bundler и yarn
gem install bundler -N
corepack enable                 # включает yarn, pnpm, etc.
corepack prepare yarn@3.6.4 --activate

bundle config set --local deployment 'true'
bundle install --jobs=4 --retry=3
yarn install --frozen-lockfile

##### 5. Подготовка БД и ассетов #####
bundle exec rails db:prepare
bundle exec rails assets:precompile

##### 6. Запуск сервисов #####
# a) Sidekiq — фоновый процесс
bundle exec sidekiq -C config/sidekiq.yml &

# b) Rails-сервер
bundle exec rails s -p 3000 -b 0.0.0.0
