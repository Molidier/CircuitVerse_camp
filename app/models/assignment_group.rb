# frozen_string_literal: true

class AssignmentGroup < ApplicationRecord
  belongs_to :assignment
  belongs_to :group

  after_destroy :destroy_assignment_if_orphan

  private

  def destroy_assignment_if_orphan
    assignment.destroy if assignment.assignment_groups.reload.empty?
  end
end
