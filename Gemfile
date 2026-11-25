# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION
DECIDIM_VERSION = { github: "decidim/decidim", branch: "release/0.32-stable" }.freeze

gem "decidim", DECIDIM_VERSION
# gem "decidim-ai", DECIDIM_VERSION
gem "decidim-collaborative_texts", DECIDIM_VERSION
gem "decidim-conferences", DECIDIM_VERSION
# gem "decidim-demographics", DECIDIM_VERSION
# gem "decidim-design", DECIDIM_VERSION
gem "decidim-elections", DECIDIM_VERSION
# gem "decidim-initiatives", DECIDIM_VERSION
gem "decidim-templates", DECIDIM_VERSION
#
gem "decidim-decidim_awesome", github: "decidim-ice/decidim-module-decidim_awesome", branch: "main"
gem "decidim-term_customizer", github: "openpoke/decidim-module-term_customizer", branch: "main"

gem "bootsnap", "~> 1.3"
gem "puma", ">= 6.3.1"
gem "rails_semantic_logger"
gem "solid_queue", "~> 1.7"
gem "solid_queue_monitor", "~> 2.2"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem "brakeman", "~> 8.0"
  gem "decidim-dev", DECIDIM_VERSION
end

group :development do
  gem "letter_opener_web"
  gem "listen"
  gem "web-console"
end

group :production do
  gem "aws-sdk-s3", require: false
end
