# frozen_string_literal: true

require "rails_helper"

describe "Decidim email footer" do
  let(:organization) do
    create(
      :organization,
      default_locale: "en",
      name: { en: "Test Organization", es: "Organización de prueba" }
    )
  end
  let(:user) { create(:user, :confirmed, organization:, locale: "en") }
  let(:mail) { Decidim::UserUpdateMailer.notify(user, %w(field1 field2 field3)) }
  let(:newsletter) do
    create(
      :newsletter,
      organization:,
      subject: { en: "Test newsletter" },
      body: { en: "Newsletter body content" }
    )
  end

  it "renders the operator information and policy links after the email content" do
    html = mail.body.decoded
    document = Nokogiri::HTML.fragment(html)
    text = document.text

    expect(text).to include("field1, field2 and field3")
    expect(text).to include("Platform run by Spektrum for the Test Organization consultation")
    expect(document.at_css("a[href='https://#{organization.host}/identity-protection.html']")).to be_present
    expect(document.css("a").map(&:text)).to include("How we protect your identity", "Help")
    expect(text.index("field1")).to be < text.index("Platform run by Spektrum")
  end

  it "renders the footer in a newsletter email after the newsletter content" do
    newsletter_mail = Decidim::NewsletterMailer.newsletter(user, newsletter)
    html = newsletter_mail.body.decoded
    document = Nokogiri::HTML.fragment(html)
    text = document.text

    expect(text).to include("Newsletter body content")
    expect(text).to include("Platform run by Spektrum for the Test Organization consultation")
    expect(document.at_css("a[href='https://#{organization.host}/identity-protection.html']")).to be_present
    expect(document.css("a").map(&:text)).to include("How we protect your identity", "Help")
    expect(text.index("Newsletter body content")).to be < text.index("Platform run by Spektrum")
  end
end
