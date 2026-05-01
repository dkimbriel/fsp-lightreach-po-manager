FactoryBot.define do
  factory :po_generation_log do
    association :po_generation_job
    level { 'info' }
    message { 'Processing project...' }

    trait :error do
      level { 'error' }
      message { 'Failed to process project' }
    end

    trait :success do
      level { 'success' }
      message { 'Successfully generated PO' }
    end

    trait :warning do
      level { 'warning' }
      message { 'PO already exists' }
    end
  end
end
