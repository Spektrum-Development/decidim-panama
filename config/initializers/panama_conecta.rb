# frozen_string_literal: true

require "omniauth"
require Rails.root.join("lib/tasks/omniauth/panama_conecta")

if ENV["PANAMA_CONECTA_CLIENT_ID"].present? &&
   ENV["PANAMA_CONECTA_CLIENT_SECRET"].present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :panama_conecta,
             ENV.fetch("PANAMA_CONECTA_CLIENT_ID"),
             ENV.fetch("PANAMA_CONECTA_CLIENT_SECRET"),
             client_token: ENV.fetch("PANAMA_CONECTA_CLIENT_SECRET"),
             client_domain: ENV.fetch("PANAMA_CONECTA_CLIENT_DOMAIN", nil),
             callback_path: "/sso/userinfo",
             client_options: {
               site: ENV.fetch("PANAMA_CONECTA_SITE")
             },
             api_site: ENV.fetch("PANAMA_CONECTA_API_SITE"),
             app_type: ENV.fetch("PANAMA_CONECTA_APP_TYPE", "web")
  end

  Decidim.omniauth_providers[:panama_conecta] = {
    enabled: true,
    icon_path: "media/images/panama_conecta-blanco.png"
  }
end
