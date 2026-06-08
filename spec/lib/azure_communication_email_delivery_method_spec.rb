# frozen_string_literal: true

require "rails_helper"

RSpec.describe AzureCommunicationEmailDeliveryMethod do
  subject(:delivery_method) do
    described_class.new(
      connection_string: "endpoint=https://texer.communication.azure.com;accesskey=#{access_key}"
    )
  end

  let(:access_key) { Base64.strict_encode64("test-access-key") }
  let(:mail) do
    Mail.new do
      from "TEXER.AI CircuitVerse <donotreply@example.azurecomm.net>"
      to "user@example.com"
      subject "Confirm your account"

      text_part do
        body "Confirm using the link."
      end

      html_part do
        content_type "text/html; charset=UTF-8"
        body "<p>Confirm using the link.</p>"
      end
    end
  end

  it "sends the message through the Azure email API" do
    captured_request = nil
    stub_request(
      :post,
      "https://texer.communication.azure.com/emails:send?api-version=2023-03-31"
    ).to_return do |request|
      captured_request = request
      { status: 202, body: { status: "Running" }.to_json }
    end

    delivery_method.deliver!(mail)

    payload = JSON.parse(captured_request.body)
    expect(payload).to include(
      "senderAddress" => "donotreply@example.azurecomm.net",
      "recipients" => { "to" => [{ "address" => "user@example.com" }] },
      "content" => {
        "subject" => "Confirm your account",
        "plainText" => "Confirm using the link.",
        "html" => "<p>Confirm using the link.</p>"
      }
    )
    expect(captured_request.headers["Authorization"]).to start_with("HMAC-SHA256 ")
    expect(captured_request.headers["X-Ms-Content-Sha256"]).to be_present
  end

  it "raises a delivery error when Azure rejects the message" do
    stub_request(:post, %r{texer\.communication\.azure\.com/emails:send})
      .to_return(status: 401, body: "Unauthorized")

    expect { delivery_method.deliver!(mail) }
      .to raise_error(described_class::DeliveryError, /401.*Unauthorized/)
  end

  it "rejects an invalid connection string" do
    expect { described_class.new(connection_string: "invalid") }
      .to raise_error(ArgumentError, /Invalid Azure/)
  end
end
