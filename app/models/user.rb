class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :po_generation_jobs, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def self.from_google(uid:, email:, full_name:)
    # Check @gofreedompower.com domain
    return nil unless /@gofreedompower\.com\z/.match?(email)

    create_with(uid: uid, full_name: full_name).find_or_create_by!(email: email)
  end
end
