# frozen_string_literal: true

module Dbc
  # Decidim renders each account email in the recipient's own language (with_user sets I18n.locale
  # for the render), so naming that language in every link makes the page match the email.
  module AccountEmailLocale
    def default_url_options # rubocop:disable Decidim/EnforcePermissionTo
      super.merge(locale: I18n.locale.to_s)
    end
  end
end
