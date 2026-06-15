FactoryBot.define do
  factory :campaign do
    sequence(:title) { |n| "Q#{n} Review Request" }
    status { :pending }

    trait :with_recipients do
      transient do
        recipients_count { 3 }
      end

      after(:create) do |campaign, evaluator|
        create_list(:recipient, evaluator.recipients_count, campaign: campaign)
      end
    end
  end
end
