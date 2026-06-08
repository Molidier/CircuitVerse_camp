# frozen_string_literal: true

require Rails.root.join("lib/azure_communication_email_delivery_method").to_s

ActionMailer::Base.add_delivery_method(
  :azure_communication_email,
  AzureCommunicationEmailDeliveryMethod,
  connection_string: ENV["AZURE_COMMUNICATION_CONNECTION_STRING"]
)
