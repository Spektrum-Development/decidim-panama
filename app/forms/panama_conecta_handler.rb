# frozen_string_literal: true

require "digest"

class PanamaConectaHandler < Decidim::AuthorizationHandler
  validate :user_valid

  def unique_id
    Digest::SHA512.hexdigest(
      "#{uid}-#{Rails.application.secret_key_base}"
    )
  end

  def to_partial_path
    "panama_conecta/form"
  end

  protected

  def uid
    panama_conecta_identity&.uid
  end

  def panama_conecta_identity
    @panama_conecta_identity ||= user&.identities&.find_by(provider: "panama_conecta")
  end

  def user_valid
    errors.add(:user, I18n.t("decidim.authorization_handlers.panama_conecta.errors.not_found")) if panama_conecta_identity.blank?
  end
end
