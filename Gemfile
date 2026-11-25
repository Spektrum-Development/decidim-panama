# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem "decidim", "0.32.3"
# gem "decidim-ai", "0.32.3"
# gem "decidim-collaborative_texts", "0.32.3"
# gem "decidim-conferences", "0.32.3"
# gem "decidim-demographics", "0.32.3"
# gem "decidim-design", "0.32.3"
# gem "decidim-elections", "0.32.3"
# gem "decidim-initiatives", "0.32.3"
# gem "decidim-templates", "0.32.3"

gem "bootsnap", "~> 1.3"

gem "puma", ">= 6.3.1"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem "brakeman", "~> 8.0"
  gem "decidim-dev", "0.32.3"
end

group :development do
  gem "letter_opener_web"
  gem "listen"
  gem "web-console"
end

group :production do
  gem "aws-sdk-s3", require: false
end
