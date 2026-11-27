# frozen_string_literal: true

module Dbc
  # Sign up, sign in, confirm, reset a password, accept an invitation, unlock. An explicit choice
  # (the language switch and every link Decidim makes carry ?locale=) or the person's own saved
  # language still wins; the browser's language and the session's earlier guess do not.
  module AccountPagesLocale
    def detect_locale # rubocop:disable Decidim/EnforcePermissionTo
      params[:locale].presence || current_user&.locale.presence || default_locale
    end
  end
end
