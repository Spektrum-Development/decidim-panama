# frozen_string_literal: true

require "omniauth"
require "omniauth/strategies/panama_conecta"

if ENV["CONECTA_CLIENT_ID"].present? &&
   ENV["CONECTA_CLIENT_TOKEN"].present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :panama_conecta,
             ENV.fetch("CONECTA_CLIENT_ID"),
             ENV.fetch("CONECTA_CLIENT_TOKEN"),
             client_token: ENV.fetch("CONECTA_CLIENT_TOKEN"),
             client_domain: ENV.fetch("CONECTA_CLIENT_DOMAIN", nil),
             full_host: ENV["CONECTA_CLIENT_DOMAIN"]&.delete_suffix("/"),
             client_options: {
               site: ENV.fetch("CONECTA_SITE")
             },
             api_site: ENV.fetch("CONECTA_API_SITE"),
             app_type: ENV.fetch("CONECTA_APP_TYPE", "web")
  end

  Decidim.omniauth_providers[:panama_conecta] = {
    enabled: true,
    icon_path: "media/images/panama_conecta-blanco.png"
  }

  # Generic verification method using panama contacts
  Decidim::Verifications.register_workflow(:panama_conecta_handler) do |workflow|
    workflow.form = "PanamaConectaHandler"
    workflow.expires_in = 1.month
  end

  # Update user's extended_data when login
  ActiveSupport::Notifications.subscribe(/decidim\.user\.omniauth_(registration|login)/) do |_name, data|
    user = Decidim::User.find_by(id: data[:user_id])
    # Verify if the user is a Panamá Conecta member
    handler = Decidim::AuthorizationHandler.handler_for("panama_conecta_handler", user:)
    if handler
      Decidim::Verifications::AuthorizeUser.call(handler, user.organization) do
        on(:ok) do
          Rails.logger.info "User #{user.id} verified as Panamá Conecta member as #{handler.unique_id}"
        end

        on(:invalid) do
          Rails.logger.error "User #{user.id} not verified as Panamá Conecta member"
        end
      end
    end
  end
end
