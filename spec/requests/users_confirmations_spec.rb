# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::Confirmations", type: :request do
  describe "GET /users/confirmation/new" do
    it "renders the resend confirmation form" do
      get new_user_confirmation_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Resend confirmation instructions")
    end
  end

  describe "POST /users/confirmation" do
    it "renders validation errors without raising an exception" do
      post user_confirmation_path, params: { user: { email: "" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Email can&#39;t be blank")
    end
  end
end
