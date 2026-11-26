# frozen_string_literal: true

require "omniauth-oauth2"
require "faraday"
require "json"
require "securerandom"
require "uri"

module OmniAuth
  module Strategies
    # Panamá Conecta's documented SSO flow is a token handoff, not OAuth2's
    # authorization-code flow. Keep the OAuth2 base for OmniAuth's auth hash
    # helpers, but implement the request and callback phases for this provider.
    class PanamaConecta < OmniAuth::Strategies::OAuth2
      option :name, "panama_conecta"
      option :client_id, ENV.fetch("PANAMA_CONECTA_CLIENT_ID", nil)
      # Panamá Conecta supplied one clientSecretToken; it is used both in the
      # login URL and as the institution secret when validating the user JWT.
      option :client_secret, ENV.fetch("PANAMA_CONECTA_CLIENT_SECRET", nil)
      option :client_token, ENV.fetch("PANAMA_CONECTA_CLIENT_SECRET", nil)
      option :client_domain, ENV.fetch("PANAMA_CONECTA_CLIENT_DOMAIN", nil)
      option :client_options, {
        site: ENV.fetch("PANAMA_CONECTA_SITE")
      }
      option :api_site, ENV.fetch("PANAMA_CONECTA_API_SITE", nil)
      option :app_type, ENV.fetch("PANAMA_CONECTA_APP_TYPE", "web")
      option :user_info_path, "/api/v1/authenticate/user"

      uid { user_info["identification"] || user_info["id_ciudadano"] || user_info["email"] }

      info do
        {
          name: user_info["full_name"],
          email: user_info["email"]
        }
      end

      extra do
        { raw_info: user_info }
      end

      def request_phase
        return fail!(:missing_client_token) if options.client_token.to_s.empty?
        return fail!(:missing_client_credentials) if options.client_id.to_s.empty? || options.client_secret.to_s.empty?

        state = SecureRandom.hex(24)
        session["omniauth.state"] = state
        store_sign_in(state, callback_url)
        remember_sign_in(state)

        # The registered clientDomain is supplied by Panamá Conecta. Avoid a
        # server-side service-sso request, which can be intercepted by its
        # browser-only Imperva/TSPD verification page.
        domain = options.client_domain.to_s.empty? ? request.base_url : options.client_domain
        return fail!(:invalid_client_domain) if domain.to_s.empty?

        query = URI.encode_www_form(
          accessToken: options.client_token,
          ownDomain: domain,
          appType: options.app_type,
          state:
        )
        redirect("#{options.client_options[:site].to_s.sub(%r{/+$}, "")}/sso/login?#{query}")
      end

      def callback_phase
        stored_sign_in
        return fail!(:csrf_detected, CallbackError.new(:csrf_detected, "CSRF detected")) if csrf_detected?

        token = request.params["token"] || request.params["accessToken"]
        return fail!(:missing_token) unless token.is_a?(String) && !token.empty?

        response = api_connection.get(options.user_info_path) do |request|
          request.headers["Authorization"] = "Bearer #{token}"
          request.headers["X-Client-Id"] = options.client_id.to_s
          request.headers["X-Client-Secret"] = options.client_secret.to_s
          request.headers["Accept"] = "application/json"
        end
        @user_info = parse_response(response).fetch("result")
        @user_info = @user_info.fetch("data", @user_info) if @user_info.is_a?(Hash)
        @access_token = ::OAuth2::AccessToken.new(client, token)

        env["omniauth.auth"] = auth_hash
        call_app!
      rescue Faraday::Error, JSON::ParserError, KeyError => e
        log_provider_error("user validation request failed (#{e.class}): #{e.message}")
        fail!(:invalid_credentials, e)
      end

      def user_info
        @user_info || {}
      end

      private

      def log_provider_error(message)
        Rails.logger.error("[PanamaConecta] #{message}") if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        log :error, message
      end

      def api_connection
        @api_connection ||= Faraday.new(url: options.api_site)
      end

      def parse_response(response)
        raise Faraday::Error, "Panamá Conecta returned HTTP #{response.status}" unless response.success?

        body = begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          content_type = response.headers["content-type"] || "unknown content type"
          endpoint = response.env.url.path
          raise Faraday::Error, "Expected JSON from #{endpoint}; received HTTP #{response.status} with #{content_type}"
        end
        raise Faraday::Error, body["message"] || "Panamá Conecta rejected the request" if body["status"] == false

        body
      end
    end
  end
end
