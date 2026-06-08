# frozen_string_literal: true

require "rails_helper"

RSpec.describe Devise::Mailer do
  describe "confirmation instructions" do
    around do |example|
      original_options = ActionMailer::Base.default_url_options
      ActionMailer::Base.default_url_options = {
        host: "texer-ai-circuitverse.app",
        protocol: "https"
      }
      example.run
    ensure
      ActionMailer::Base.default_url_options = original_options
    end

    let(:user) { build_stubbed(:user, email: "student@example.com") }
    let(:mail) { described_class.confirmation_instructions(user, "confirmation-token") }

    it "uses TEXER.AI CircuitVerse branding" do
      expect(mail.subject).to eq("Verify your email for TEXER.AI CircuitVerse")
      expect(mail.body.encoded).to include("Welcome to TEXER.AI CircuitVerse")
      expect(mail.body.encoded).to include("Verify my email")
    end

    it "links to the production website confirmation endpoint" do
      expect(mail.body.encoded).to include(
        "https://texer-ai-circuitverse.app/users/confirmation?confirmation_token=confirmation-token"
      )
    end

    it "explains what verification does" do
      expect(mail.body.encoded).to include("verify this email address and activate your account")
      expect(mail.body.encoded).to include("After verification, you can log in")
    end
  end
end
