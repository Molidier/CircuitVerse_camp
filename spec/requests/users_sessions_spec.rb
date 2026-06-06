# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  before do
    rsa_private = OpenSSL::PKey::RSA.generate(2048)
    rsa_public = rsa_private.public_key

    allow(JsonWebToken).to receive_messages(private_key: rsa_private, public_key: rsa_public)
  end

  describe "POST /users/sign_in" do
    it "signs in a confirmed user" do
      user = create(:user, :confirmed, password: "password123")

      post user_session_path, params: {
        user: {
          email: user.email,
          password: "password123"
        }
      }

      expect(response).to redirect_to(root_path)
      expect(response.cookies["cvt"]).to be_present
    end

    it "shows an unconfirmed message after the confirmation grace period expires" do
      user = create(:user, password: "password123")
      user.update_columns(created_at: 40.days.ago, confirmation_sent_at: 40.days.ago)

      post user_session_path, params: {
        user: {
          email: user.email,
          password: "password123"
        }
      }

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("You have to confirm your email address before continuing.")
    end
  end
end
