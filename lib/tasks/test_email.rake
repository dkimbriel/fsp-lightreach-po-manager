namespace :email do
  desc "Send a test email via Google service account"
  task test: :environment do
    puts "Sending test email..."

    # Create a simple test email
    class TestMailer < ApplicationMailer
      def test_email
        mail(
          to: "dkimbriel@gofreedompower.com",
          from: "project_sunrise@gofreedompower.com",
          subject: "[TEST] Google Service Account Email Test",
          body: "This is a test email sent via Google service account at #{Time.now}.\n\nIf you receive this, the email configuration is working correctly!"
        )
      end
    end

    begin
      message = TestMailer.test_email
      message.send_google
      puts "✓ Test email sent successfully to dkimbriel@gofreedompower.com"
      puts "  Check your inbox (it may take a few moments to arrive)"
    rescue StandardError => e
      puts "✗ Failed to send test email"
      puts "  Error: #{e.class} - #{e.message}"
      puts "\n  Backtrace:"
      puts e.backtrace.first(5).map { |line| "    #{line}" }.join("\n")

      # Check for common issues
      if e.message.include?("credentials")
        puts "\n  ⚠ This looks like a credentials issue."
        puts "    Make sure you've set up Rails credentials with:"
        puts "    - google_project_id"
        puts "    - google_client_email"
        puts "    - google_private_key_id"
        puts "    - google_private_key"
        puts "    - google_client_id"
      elsif e.message.include?("delegation")
        puts "\n  ⚠ This looks like a domain delegation issue."
        puts "    Make sure your service account has domain-wide delegation"
        puts "    and the required Gmail API scopes are authorized."
      end
    end
  end
end
