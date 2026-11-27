# frozen_string_literal: true

# The account pages speak the organisation's language (Spanish for a Panamá project) unless the
# visitor chose otherwise, and the links in Decidim's account emails open in the email's language.
#
# Decidim picks a page's language from, in order: ?locale= in the address, the signed-in person's
# saved language, the session, then the browser's language, and only then the organisation's
# default. A confirmation link carries no ?locale= and is often opened signed out, in a fresh
# browser or a mail app, so the browser decided: a person who registered in Spanish, got the email
# in Spanish and confirmed on an English-set phone saw English. The image is unchanged (D05, D90);
# this is mounted as an initializer on every Decidim container, the worker included, which sends
# the emails.

Rails.application.config.to_prepare do
  %w(Registrations Sessions Confirmations Passwords Invitations Unlocks OmniauthRegistrations).each do |name|
    "Decidim::Devise::#{name}Controller".constantize.prepend(Dbc::AccountPagesLocale)
  end
  Decidim::DecidimDeviseMailer.prepend(Dbc::AccountEmailLocale)
end

Rails.application.config.after_initialize do
  # Rails' own fallbacks go to the default language, which a deployment may set to English; the
  # Ngäbere reader's is Spanish whatever the default
  I18n.fallbacks.map(gym: :es) if Decidim.available_locales.include?(:gym) && I18n.respond_to?(:fallbacks)
end
