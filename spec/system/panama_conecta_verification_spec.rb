# frozen_string_literal: true

require "rails_helper"

describe "Panamá Conecta verification" do
  let(:organization) { create(:organization, available_authorizations: ["panama_conecta_handler"]) }
  let(:uid) { "00000000-0000-4000-8000-000000000001" }
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "panama_conecta",
      uid:,
      info: {
        name: "Panama Test User",
        email: "panama.test@example.org",
        nickname: "panama_test_user",
        first_name: "Panama",
        last_name: "Test User"
      },
      credentials: {},
      extra: { raw_info: { "user_id" => uid } }
    )
  end

  around do |example|
    original_test_mode = OmniAuth.config.test_mode
    original_mock_auth = OmniAuth.config.mock_auth[:panama_conecta]

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:panama_conecta] = auth_hash
    example.run
  ensure
    OmniAuth.config.test_mode = original_test_mode
    if original_mock_auth
      OmniAuth.config.mock_auth[:panama_conecta] = original_mock_auth
    else
      OmniAuth.config.mock_auth.delete(:panama_conecta)
    end
  end

  before do
    switch_to_host(organization.host)
  end

  def start_panama_conecta_sign_in
    visit decidim.new_user_session_path
    find('a[href*="panama_conecta"]').click
  end

  def visit_authorizations
    within_user_menu do
      click_on "My account"
    end

    click_on "Authorizations"
  end

  it "creates an account and grants the Panamá Conecta authorization" do
    start_panama_conecta_sign_in

    check :registration_user_tos_agreement
    check :registration_user_newsletter
    within "#omniauth-register-form" do
      click_on "Create an account"
    end

    expect_user_logged

    user = organization.users.find_by!(email: "panama.test@example.org")
    identity = user.identities.find_by!(provider: "panama_conecta", uid:)
    authorization = Decidim::Authorization.find_by!(user:, name: "panama_conecta_handler")

    expect(identity).to be_present
    expect(authorization.unique_id).to eq(PanamaConectaHandler.new(user:).unique_id)
    expect(authorization.granted_at).to be_present
  end

  context "when user exists" do
    let(:user) { create(:user, :confirmed, organization:, email: "panama.test@example.org") }
    let!(:identity) { create(:identity, user:, organization:, provider: "panama_conecta", uid:) }

    it "grants the authorization when an existing identity signs in again" do
      login_as user, scope: :user
      visit decidim.root_path
      visit_authorizations

      within ".authorizations-list" do
        click_on "Panamá Conecta"
      end

      expect(page).to have_content("Verify with Panamá Conecta")
      click_on "Send"
      expect(page).to have_content("You have been successfully authorized")
      expect(Decidim::Authorization.find_by!(user:, name: "panama_conecta_handler").granted_at).to be_present
    end
  end
end
