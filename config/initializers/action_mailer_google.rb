# Load Google::Gmail service
require Rails.root.join("app/services/google.rb")

module ActionMailer
  # Shared send_google implementation
  module GoogleMailer
    @@dev_environment_whitelist = [
      "dkimbriel@gofreedompower.com",
      "dkimbriel@freedomsolarpower.com",
      "davidkimb92@gmail.com"
    ]

    def send_google
      return unless message.from && message.from.length.positive?
      return if Rails.env.test?

      # Filters to addresses in dev to only ones in the dev_environment_whitelist
      if Rails.env.development?
        message.to = message.to&.select { |address| @@dev_environment_whitelist.include?(address) }
        message.cc = message.cc&.select { |address| @@dev_environment_whitelist.include?(address) }
        message.bcc = message.bcc&.select { |address| @@dev_environment_whitelist.include?(address) }
      end

      encoded_body = message.encoded
      encoded_body.prepend("Bcc: #{message.bcc[0]}\n") if message.bcc && message.bcc.length.positive?
      from_account = message.from[0].gsub("freedomsolar.com", "freedomsolarpower.com")
      Rails.logger.info "Sending email via Google from: #{from_account}"
      Google::Gmail.new(from_account).send_email_raw(encoded_body, from_account)
    end
  end

  # Patch regular MessageDelivery
  class MessageDelivery
    include GoogleMailer
  end

  # Patch Parameterized MessageDelivery
  module Parameterized
    class MessageDelivery
      include ActionMailer::GoogleMailer
    end
  end
end
