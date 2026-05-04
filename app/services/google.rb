module Google
  require "google/apis/gmail_v1"
  require "googleauth"

  class Gmail
    include Google::Apis::GmailV1
    attr_accessor :gmail

    @@cred_file_path = "google-service-account.json"

    def initialize(admin)
      @admin = admin
      Google::Apis.logger.level = Logger::FATAL
      build_credentials_file unless File.exist?(@@cred_file_path)
      authenticate
      start_service
    end

    def build_credentials_file
      credentials = {
        "type": "service_account",
        "project_id": Rails.application.credentials.google_project_id,
        "client_email": Rails.application.credentials.google_client_email,
        "private_key_id": Rails.application.credentials.google_private_key_id,
        "private_key": Rails.application.credentials.google_private_key.gsub('\\n', "\n"),
        "client_id": Rails.application.credentials.google_client_id.to_s,
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/#{ERB::Util.url_encode(Rails.application.credentials.google_client_email)}"
      }

      File.open(@@cred_file_path, "w+") do |f|
        f.write(credentials.to_json)
      end
    end

    def authenticate
      scope = [
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://mail.google.com/"
      ]

      @authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: file = File.open(@@cred_file_path),
        scope:
      )
      file.close
      @authorizer.sub = @admin
      @authorizer.fetch_access_token!
    end

    def start_service
      @gmail = GmailService.new
      @gmail.authorization = @authorizer
    end

    def send_email(to:, from:, subject:, body:)
      to = MessagePartHeader.new(name: "To", value: to)
      from = MessagePartHeader.new(name: "From", value: from)
      subject = MessagePartHeader.new(name: "Subject", value: subject)
      headers = [ to, from, subject ]

      message_body = MessagePartBody.new(data: body)
      message_part = MessagePart.new(
        headers:,
        body: message_body,
        mime_type: "text/html",
        part_id: "1"
      )
      message = Message.new(
        payload: message_part
      )
      @gmail.send_user_message(from, message)
    end

    def send_email_raw(body, from)
      message = Google::Apis::GmailV1::Message.new(
        raw: body.to_s
      )
      @gmail.send_user_message(from, message)
    end
  end
end
