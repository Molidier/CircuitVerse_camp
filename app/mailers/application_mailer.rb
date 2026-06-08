# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { "TEXER.AI CircuitVerse <#{ENV.fetch("AZURE_EMAIL_SENDER", "noreply@circuitverse.org")}>" }
  layout "mailer"
end
