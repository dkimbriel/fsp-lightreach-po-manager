module ActionMailer
  module Parameterized
    class MessageDelivery
      @@dev_environment_whitelist = [
        'dkimbriel@gofreedompower.com',
        'dkimbriel@freedomsolarpower.com',
        'davidkimb92@gmail.com'
      ]

      def send_google
        return unless from && from.length.positive?
        return if Rails.env.test?

        # Filters to addresses in dev to only ones in the dev_environment_whitelist
        if Rails.env.development?
          self.to = to&.select { |address| @@dev_environment_whitelist.include?(address) }&.join(', ')
          self.cc = cc&.select { |address| @@dev_environment_whitelist.include?(address) }&.join(', ')
          self.bcc = bcc&.select { |address| @@dev_environment_whitelist.include?(address) }&.join(', ')
        end

        encoded_body = encoded
        encoded_body.prepend("Bcc: #{bcc[0]}\n") if bcc && bcc.length.positive?
        from_account = from[0].gsub('freedomsolar.com', 'freedomsolarpower.com')
        Rails.logger.info "Sending email via Google from: #{from_account}"
        Google::Gmail.new(from_account).send_email_raw(encoded_body, from_account)
      end
    end
  end
end
