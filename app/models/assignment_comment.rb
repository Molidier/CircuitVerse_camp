# frozen_string_literal: true

class AssignmentComment < ApplicationRecord
  belongs_to :assignment
  belongs_to :user

  validates :body, presence: true, length: { maximum: 10_000 }
end
