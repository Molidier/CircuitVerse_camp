# frozen_string_literal: true

class GradePolicy < ApplicationPolicy
  attr_reader :user, :grade

  def initialize(user, grade)
    @user = user
    @grade = grade
  end

  def mentor?
    return false if grade.assignment.blank?

    grade.assignment.groups.any? do |g|
      g.primary_mentor_id == user.id ||
        g.group_members.exists?(user_id: user.id, mentor: true) ||
        g.group_members.exists?(user_id: user.id, ta: true)
    end
  end
end
