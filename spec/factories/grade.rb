# frozen_string_literal: true

FactoryBot.define do
  factory :grade do
    association :grader, factory: :user
    association :project
    association :assignment
    grade { "80" }
  end
end
