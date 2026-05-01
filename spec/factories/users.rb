FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@gofreedompower.com" }
    sequence(:uid) { |n| "google_#{n}" }
    full_name { "Test User" }
  end
end
