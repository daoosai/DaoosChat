#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

### 0. Переменные окружения ###
export RAILS_ENV=production
export NODE_ENV=production
export INSTALLATION_ENV=codex
export DATABASE_URL=postgres://postgres:supersecure123@localhost:5432/chatwoot
export REDIS_URL=redis://:redispass123@localhost:6379
export FRONTEND_URL=https://chat.daoos.ai
export NODE_OPTIONS="--max-old-space-size=4096"
export SECRET_KEY_BASE=11860b3dd8e707e0c25f8fb5cd9ada771e9b437b17b0a4492bba36850cbfe71451d0451d264122830e831f55706bbd4352cb18b6e7dddba0cf61c7b63cc5d2de

echo "=== [1/6] Установка системных пакетов ==="
sudo apt-get update -yq
sudo apt-get install -yq --no-install-recommends \
  build-essential git curl gnupg \
  libpq-dev pkg-config \
  redis-server \
  postgresql-16 postgresql-client-16 postgresql-server-dev-16 \
  ca-certificates make

### 1.1 Установка pgvector (если нет в репо)
if ! psql -V | grep -q " 16"; then
  echo "❌ PostgreSQL 16 не найден"; exit 1
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'vector'" | grep -q 1; then
  echo "=== Компиляция pgvector ==="
  git clone --depth 1 https://github.com/pgvector/pgvector.git /tmp/pgvector
  (cd /tmp/pgvector && make && sudo make install)
fi

echo "=== [2/6] Настройка PostgreSQL ==="
sudo service postgresql start
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'supersecure123';" || true
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'chatwoot'" | grep -q 1 || \
  sudo -u postgres createdb chatwoot
sudo -u postgres psql -d chatwoot -c "CREATE EXTENSION IF NOT EXISTS vector;"

echo "=== [3/6] Настройка Redis ==="
sudo sed -i "s/^# *requirepass .*$/requirepass redispass123/" /etc/redis/redis.conf
sudo service redis-server restart

echo "=== [4/6] Установка Ruby / Node зависимостей ==="
gem install bundler:2.5.16 -N

corepack enable
corepack prepare pnpm@10.0.0 --activate

bundle config set --local deployment 'true'
bundle install --jobs=4 --retry=3 --without development test

# pnpm — оффлайн, без лишней проверки
pnpm install --prefer-offline --no-frozen-lockfile

echo "=== [5/6] Подготовка БД и ассетов ==="
bundle exec rails db:prepare
bundle exec rails assets:precompile

echo "=== [6/6] Запуск сервисов ==="
bundle exec sidekiq -C config/sidekiq.yml &
bundle exec rails s -p 3000 -b 0.0.0.0
