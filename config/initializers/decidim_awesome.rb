# frozen_string_literal: true

Decidim::DecidimAwesome.configure do |config|
  # Enable hashcash by default for signup and login to prevent spam and abuse
  config.hashcash_signup = true
  config.hashcash_login = true
  # Disable Intergram for admins and public users as it uses external chat services that may conflict with privacy policies
  config.intergram_for_admins = :disabled
  config.intergram_for_public = :disabled
end
