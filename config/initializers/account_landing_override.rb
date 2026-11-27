# frozen_string_literal: true

# Where Decidim sends a person after registering, confirming their address or signing in, when no
# page of their own was waiting: the project's process page, not the site's root.
#
# The project's address is one site (D92): its root is the front door, a static page that cannot
# show Decidim's messages. Devise sends people to the root after these steps, with the message that
# tells them what happened ("we have sent you a link to confirm your address") waiting to be shown,
# so they landed on the front door and the message was lost. Signing out and every link home still
# go to the front door. The image is unchanged (D05, D92); mounted as an initializer like locale.rb.

Rails.application.config.to_prepare do
  [Decidim::ApplicationController,
   *%w(Registrations Sessions Confirmations Passwords Invitations Unlocks OmniauthRegistrations)
     .map { |name| "Decidim::Devise::#{name}Controller".constantize }].each do |controller|
    controller.prepend(Dbc::AccountLanding)
  end
end
