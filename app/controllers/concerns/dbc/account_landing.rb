# frozen_string_literal: true

module Dbc
  module AccountLanding
    protected

    # Registered, address not confirmed yet: Devise's default is the root
    def after_inactive_sign_up_path_for(_resource)
      dbc_account_landing
    end

    # Signed in or confirmed with no page stored to return to: Devise's default is the root
    def signed_in_root_path(_resource_or_scope)
      dbc_account_landing
    end

    private

    # In the language the step was taken in, which the message is written in
    def dbc_account_landing
      slug = ENV.fetch("PROJECT_SLUG", "")
      path = slug.empty? ? "/processes" : "/processes/#{slug}"
      "#{path}?locale=#{I18n.locale}"
    end
  end
end
