# frozen_string_literal: true

module Dbc
  module AccountLanding
    protected

    # Registered, address not confirmed yet: Devise's default is the root
    def after_inactive_sign_up_path_for(_resource)
      dbc_account_landing || super
    end

    # Signed in or confirmed with no page stored to return to: Devise's default is the root
    def signed_in_root_path(_resource_or_scope)
      dbc_account_landing || super
    end

    private

    # In the language the step was taken in, which the message is written in
    def dbc_account_landing
      slug = ENV.fetch("PROJECT_SLUG", "")
      return "#{I18n.locale}/processes/#{slug}" if slug.present?

      "#{I18n.locale}/processes" if Decidim::ParticipatoryProcess.any? # rubocop:disable Decidim/OrganizationScopedFinder
    end
  end
end
