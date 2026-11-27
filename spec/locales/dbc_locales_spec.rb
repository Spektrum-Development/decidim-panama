# frozen_string_literal: true

require "rails_helper"

describe "DBC locale content" do
  it "uses the intended participant-facing proposal term in English and Spanish" do
    expect(I18n.t("activerecord.models.decidim/proposals/proposal.one", locale: :en)).to eq("Submission")
    expect(I18n.t("activerecord.models.decidim/proposals/proposal.one", locale: :es)).to eq("Aporte")
  end

  it "provides document review labels in English and Spanish" do
    expect(I18n.t("dbc.document_hold.awaiting", locale: :en)).to eq("Awaiting a check: the team will publish a checked copy")
    expect(I18n.t("dbc.document_hold.awaiting", locale: :es)).to eq("En revisión: el equipo publicará una copia revisada")
  end
end
