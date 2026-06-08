# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "net/http"
require "openssl"
require "securerandom"
require "time"
require "uri"

class AzureCommunicationEmailDeliveryMethod
  API_VERSION = "2023-03-31"

  class DeliveryError < StandardError; end

  def initialize(settings)
    @endpoint, @access_key = parse_connection_string(settings[:connection_string])
    @open_timeout = settings.fetch(:open_timeout, 10)
    @read_timeout = settings.fetch(:read_timeout, 30)
  end

  def deliver!(mail)
    uri = URI("#{@endpoint}/emails:send?api-version=#{API_VERSION}")
    body = JSON.generate(payload_for(mail))
    date = Time.now.utc.httpdate
    content_hash = Base64.strict_encode64(Digest::SHA256.digest(body))
    string_to_sign = "POST\n#{uri.request_uri}\n#{date};#{uri.host};#{content_hash}"
    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest("SHA256", Base64.strict_decode64(@access_key), string_to_sign)
    )

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] =
      "HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=#{signature}"
    request["Content-Type"] = "application/json"
    request["Operation-Id"] = SecureRandom.uuid
    request["x-ms-content-sha256"] = content_hash
    request["x-ms-date"] = date
    request.body = body

    response = perform_request(uri, request)
    return response if response.is_a?(Net::HTTPSuccess)

    raise DeliveryError,
          "Azure Communication Services email request failed (#{response.code}): " \
          "#{response.body.to_s.slice(0, 500)}"
  end

  private

  def parse_connection_string(connection_string)
    values = connection_string.to_s.split(";").filter_map do |entry|
      key, value = entry.split("=", 2)
      [key.downcase, value] if key.present? && value.present?
    end.to_h

    endpoint = values["endpoint"]&.delete_suffix("/")
    access_key = values["accesskey"]
    uri = URI(endpoint.to_s)

    unless uri.is_a?(URI::HTTPS) && uri.host.present? && access_key.present?
      raise ArgumentError, "Invalid Azure Communication Services connection string"
    end

    [endpoint, access_key]
  rescue URI::InvalidURIError
    raise ArgumentError, "Invalid Azure Communication Services connection string"
  end

  def payload_for(mail)
    {
      senderAddress: mail.from&.first,
      recipients: recipients_for(mail),
      content: content_for(mail)
    }.tap do |payload|
      attachments = attachments_for(mail)
      payload[:attachments] = attachments if attachments.any?
    end
  end

  def recipients_for(mail)
    {
      to: addresses_for(mail.to),
      cc: addresses_for(mail.cc),
      bcc: addresses_for(mail.bcc)
    }.compact_blank
  end

  def addresses_for(addresses)
    Array(addresses).map { |address| { address: address } }
  end

  def content_for(mail)
    content = { subject: mail.subject.to_s }

    if mail.multipart?
      content[:plainText] = mail.text_part.decoded if mail.text_part
      content[:html] = mail.html_part.decoded if mail.html_part
    elsif mail.mime_type == "text/html"
      content[:html] = mail.body.decoded
    else
      content[:plainText] = mail.body.decoded
    end

    content
  end

  def attachments_for(mail)
    mail.attachments.map do |attachment|
      {
        name: attachment.filename,
        contentType: attachment.mime_type,
        contentInBase64: Base64.strict_encode64(attachment.body.decoded)
      }
    end
  end

  def perform_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout
    http.request(request)
  end
end
