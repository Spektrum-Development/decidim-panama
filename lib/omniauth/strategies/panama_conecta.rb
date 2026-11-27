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
      option :client_id, ENV.fetch("CONECTA_CLIENT_ID", nil)
      option :client_domain, ENV.fetch("CONECTA_CLIENT_DOMAIN", nil)
      # Panamá Conecta supplied one clientSecretToken; it is used both in the
      # login URL and as the institution secret when validating the user JWT.
      option :client_secret, ENV.fetch("CONECTA_CLIENT_TOKEN", nil)
      option :client_token, ENV.fetch("CONECTA_CLIENT_TOKEN", nil)
      option :client_options, {
        site: ENV.fetch("CONECTA_SITE", nil)
      }
      option :api_site, ENV.fetch("CONECTA_API_SITE", nil)
      option :app_type, ENV.fetch("CONECTA_APP_TYPE", "web")
      option :service_sso_path, "/api/sso/service-sso"
      option :user_info_path, "/api/user/user-info"

      # Prefer Panamá Conecta's opaque account ID; fall back to fields returned by older endpoints.
      uid do
        user_info["user_id"] || user_info["identification"] || user_info["id_ciudadano"] ||
          user_info["cedula"] || user_info["email"] || user_info["correo_electronico"]
      end

      info do
        {
          name: user_info["nombre_completo"] || user_info["full_name"] || composed_name,
          email: user_info["correo_electronico"] || user_info["email"],
          first_name: user_info["primer_nombre"],
          last_name: %w(apellido_paterno apellido_materno apellido_casada)
                     .filter_map { |field| user_info[field].presence }.join(" ")
        }
      end

      extra do
        safe_fields = %w(
          user_id nombre_completo correo_electronico primer_nombre segundo_nombre
          apellido_paterno apellido_materno apellido_casada
        )
        { raw_info: user_info.slice(*safe_fields) }
      end

      def request_phase
        return fail!(:missing_client_token) if options.client_token.to_s.empty?
        return fail!(:missing_client_credentials) if options.client_id.to_s.empty? || options.client_secret.to_s.empty?

        client_domain = configured_client_domain

        service_response = api_connection.post(options.service_sso_path) do |request|
          request.headers["Content-Type"] = "application/json"
          request.headers["User-Agent"] = "Ruby/#{RUBY_VERSION}"
          request.headers["Accept"] = "application/json"
          request.headers["Origin"] = options.client_options[:site].to_s.sub(%r{/+$}, "")
          request.headers["referer"] = client_domain
          request.body = JSON.generate(
            clientToken: options.client_token
          )
        end
        service_data = parse_response(service_response)
        domain = service_data.dig("result", "data", "clientdomain")
        client_type = service_data.dig("result", "data", "clienttype")
        return fail!(:invalid_client_domain) if domain.to_s.empty?

        query = URI.encode_www_form(
          accessToken: options.client_token,
          ownDomain: domain,
          appType: options.app_type,
          clientType: client_type
        )

        redirect("#{options.client_options[:site].to_s.sub(%r{/+$}, "")}/sso/login?#{query}")
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
        log_provider_error("service-sso connection failed (#{e.class}): #{e.message}")
        fail!(:failed_to_connect, e)
      rescue Faraday::Error, JSON::ParserError, KeyError => e
        log_provider_error("service-sso response was invalid (#{e.class}): #{e.message}")
        fail!(:invalid_response, e)
      end

      def callback_phase
        stored_sign_in
        # return fail!(:csrf_detected, CallbackError.new(:csrf_detected, "CSRF detected")) if csrf_detected?

        # AIG's sample slices the raw query string; Rack params converts literal '+' to a space.
        token = raw_query_param("token")
        return fail!(:missing_token) unless token.is_a?(String) && !token.empty?

        response = api_connection.post(options.user_info_path) do |request|
          request.headers["Authorization"] = "Bearer #{token}"
          request.headers["Content-Type"] = "application/json"
          request.headers["Origin"] = options.client_options[:site].to_s.sub(%r{/+$}, "")
          request.headers["Referer"] = configured_client_domain
        end
        @user_info = parse_response(response).fetch("result")
        @user_info = @user_info.fetch("data", @user_info) if @user_info.is_a?(Hash)
        env["omniauth.auth"] = auth_hash
        call_app!
      rescue Faraday::Error, JSON::ParserError, KeyError => e
        log_provider_error("user validation request failed (#{e.class}): #{e.message}")
        fail!(:invalid_credentials, e)
      end

      def user_info
        @user_info || {}
      end

      # This provider's callback token is one-time input to user validation, not a credential to
      # retain. Override the OAuth2 fetcher method because OmniAuth merges inherited DSL blocks.
      def credentials
        {}
      end

      def composed_name
        %w(primer_nombre segundo_nombre apellido_paterno apellido_materno apellido_casada)
          .filter_map { |field| user_info[field].presence }.join(" ")
      end

      private

      def log_provider_error(message)
        Rails.logger.error("[PanamaConecta] #{message}") if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        log :error, message
      end

      # Preserve the callback value exactly as supplied. The integration sample reads search.slice(7)
      # rather than URLSearchParams, so decoding '+' as a form-space would corrupt the token.
      def raw_query_param(name)
        request.env.fetch("QUERY_STRING", "").split("&").each do |pair|
          key, value = pair.split("=", 2)
          return value.to_s if key == name
        end
        nil
      end

      def api_connection
        @api_connection ||= Faraday.new(url: options.api_site)
      end

      def configured_client_domain
        options.client_domain.presence || request.base_url
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
