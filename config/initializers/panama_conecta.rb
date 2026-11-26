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
               site: ENV.fetch("CONECTA_SITE", "https://qapanamaconecta.aig.gob.pa")
             },
             api_site: ENV.fetch("CONECTA_API_SITE", "https://apiqapanamaconecta.aig.gob.pa:8443"),
             app_type: ENV.fetch("CONECTA_APP_TYPE", "web")
  end

  Decidim.omniauth_providers[:panama_conecta] = {
    enabled: true,
    icon_path: "media/images/panama_conecta-blanco.png"
  }
end
