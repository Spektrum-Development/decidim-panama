#!/bin/bash

# Puma's configured PID file is under tmp/pids, which is removed during image cleanup.
mkdir -p tmp/pids

# Check all the gems are installed or fails.
bundle check
if [ $? -ne 0 ]; then
	echo "❌ Gems in Gemfile are not installed, aborting..."
	exit 1
else
	echo "✅ Gems in Gemfile are installed"
fi

# Check no migrations are pending migrations
if [ -z "$SKIP_MIGRATIONS" ]; then
	bundle exec rails db:prepare || exit 1
	echo "✅ Databases are prepared"
	bundle exec rails data:migrate || exit 1
	echo "✅ Data migrations are all up"
else
	echo "⚠️ Skipping migrations"
fi

echo "🚀 $@"
exec "$@"