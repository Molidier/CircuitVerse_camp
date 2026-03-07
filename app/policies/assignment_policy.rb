# frozen_string_literal: true

class AssignmentPolicy < ApplicationPolicy
  attr_reader :user, :assignment

  def initialize(user, assignment)
    super
    @user = user
    @assignment = assignment
  end

  def show?
    user.admin? || assignment.groups.any? { |g| g.primary_mentor_id == user.id || g.group_members.exists?(user_id: user.id) }
  end

  def admin_access?
    user.admin? || assignment.groups.any? { |g| g.primary_mentor_id == user.id }
  end

  def mentor_access?
    user.admin? || assignment.groups.any? do |g|
      g.primary_mentor_id == user.id ||
        g.group_members.exists?(user_id: user.id, mentor: true) ||
        g.group_members.exists?(user_id: user.id, ta: true)
    end
  end

  def start?
    # assignment should not be closed and not submitted
    assignment.status != "closed" \
      && !Project.exists?(author_id: user.id, assignment_id: assignment.id)
  end

  def edit?
    assignment.status != "closed"
  end

  def reopen?
    raise CustomAuthError, "Project is already open" if assignment.status == "open"

    true
  end

  def close?
    admin_access?
  end

  def can_be_graded?
    mentor_access? && assignment.graded? && (assignment.deadline - Time.current).negative?
  end

  def show_grades?
    assignment.graded? && Time.current > assignment.deadline
  end
end
