# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "uri"
require_relative "../../../../lib/omniauth/strategies/panama_conecta"

module OmniAuth::Strategies
  RSpec.describe PanamaConecta do
    let(:client_id) { "panama-client-id" }
    let(:client_token) { "client+token/base==" }
    let(:client_domain) { "https://panama.example.test" }
    let(:site) { "https://qapanamaconecta.example.test" }
    let(:api_site) { "https://api.example.test" }
    let(:captured_auth) { {} }
    let(:app) do
      lambda do |env|
        captured_auth[:auth] = env["omniauth.auth"]
        [200, { "content-type" => "text/plain" }, ["ok"]]
      end
    end
    let(:strategy) do
      described_class.new(
        app,
        client_id,
        client_token,
        client_token:,
        client_domain:,
        client_options: { site: },
        api_site:,
        app_type: "web"
      )
    end

    def set_request_env(strategy, path, session: {})
      env = Rack::MockRequest.env_for(path, "rack.session" => session)
      strategy.instance_variable_set(:@env, env)
    end

    def faraday_response(payload, path: "/api/sso/service-sso", status: 200)
      env = Faraday::Env.new(
        status:,
        response_body: JSON.generate(payload),
        response_headers: { "content-type" => "application/json" },
        url: URI("#{api_site}#{path}")
      )
      Faraday::Response.new(env)
    end

    def capture_post(connection, response)
      requests = []
      allow(connection).to receive(:post) do |path, &block|
        request = Struct.new(:headers, :body).new({}, nil)
        block.call(request)
        requests << { path:, headers: request.headers, body: request.body }
        response
      end
      requests
    end

    describe "#request_phase" do
      it "fetches the registered domain and redirects with the returned login parameters" do
        connection = double("Faraday connection")
        service_data = {
          "status" => true,
          "result" => { "data" => { "clientdomain" => "https://registered.example.test", "clienttype" => "web" } }
        }
        requests = capture_post(connection, faraday_response(service_data))
        allow(strategy).to receive(:api_connection).and_return(connection)
        set_request_env(strategy, "/users/auth/panama_conecta")

        status, headers, = strategy.request_phase

        expect(status).to eq(302)
        location = URI(headers["location"])
        expect(location.host).to eq("qapanamaconecta.example.test")
        expect(location.path).to eq("/sso/login")
        expect(URI.decode_www_form(location.query).to_h).to include(
          "accessToken" => client_token,
          "ownDomain" => "https://registered.example.test",
          "appType" => "web",
          "clientType" => "web"
        )
        expect(requests).to contain_exactly(
          hash_including(
            path: "/api/sso/service-sso",
            body: JSON.generate(clientToken: client_token),
            headers: hash_including(
              "Content-Type" => "application/json",
              "Accept" => "application/json",
              "User-Agent" => "Ruby/#{RUBY_VERSION}",
              "Origin" => site,
              "referer" => client_domain
            )
          )
        )
      end

      it "uses the current Decidim request host as the referer when no client domain is configured" do
        connection = double("Faraday connection")
        service_data = {
          "status" => true,
          "result" => { "data" => { "clientdomain" => "https://registered.example.test", "clienttype" => "web" } }
        }
        requests = capture_post(connection, faraday_response(service_data))
        allow(strategy).to receive(:api_connection).and_return(connection)
        allow(strategy.options).to receive(:client_domain).and_return(nil)
        set_request_env(strategy, "/users/auth/panama_conecta")

        strategy.request_phase

        expect(requests.first[:headers]["referer"]).to eq("http://example.org")
      end
    end

    describe "#callback_phase" do
      it "preserves a literal plus in the callback token and maps the returned user profile" do
        fixture_path = File.expand_path("../../../../spec/fixtures/oauth_callback_result.json", __dir__)
        fixture = JSON.parse(File.read(fixture_path))
        connection = double("Faraday connection")
        requests = capture_post(
          connection,
          faraday_response(fixture, path: "/api/user/user-info")
        )
        allow(strategy).to receive(:api_connection).and_return(connection)
        set_request_env(
          strategy,
          "/users/auth/panama_conecta/callback?token=+raw%2Btoken==",
          session: { "omniauth.state" => "pending-state" }
        )

        status, = strategy.callback_phase

        expect(status).to eq(200)
        expect(requests).to contain_exactly(
          hash_including(
            path: "/api/user/user-info",
            headers: hash_including(
              "Authorization" => "Bearer +raw%2Btoken==",
              "Content-Type" => "application/json",
              "Origin" => site,
              "Referer" => client_domain
            )
          )
        )

        auth = captured_auth.fetch(:auth)
        expect(auth.uid).to eq("00000000-0000-4000-8000-000000000000")
        expect(auth.info).to include(
          name: "Test OAuth Example User",
          email: "oauth.user@example.org",
          first_name: "Test",
          last_name: "Example User"
        )
        expect(auth.credentials).to eq({})
        expect(auth.extra.raw_info).to include("user_id", "nombre_completo", "correo_electronico")
        expect(auth.extra.raw_info).not_to include("cedula", "token", "associated_apps_token")
      end
    end
  end
end
