FactoryBot.define do
  factory :recipient do
    association :campaign
    sequence(:name) { |n| "Customer #{n}" }
    sequence(:contact) { |n| "customer#{n}@example.com" }
    status { :queued }
  end
end
