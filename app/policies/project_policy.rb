# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  attr_reader :user, :project

  def initialize(user, project)
    @user = user
    @project = project
    simulator_error = "Project has been moved or deleted. If you are the owner " \
                      "of the project, Please check your project access privileges."
    @simulator_exception = CustomAuthException.new(simulator_error)
  end

  def can_feature?
    user.present? && user.admin? && project.project_access_type == "Public"
  end

  def user_access?
    check_edit_access? || (user.present? && user.admin?)
  end

  def check_edit_access?
    return false if user.nil? || project.project_submission

    project.author_id == user.id ||
      Collaboration.exists?(project_id: project.id, user_id: user.id)
  end

  # Student privacy guarantee
  # Assignment projects are always Private (enforced by Project#check_validity).
  # For a Private project a viewer must be:
  #   1. The author (owner of the circuit)
  #   2. A mentor of the assignment's group (primary_mentor OR mentor group_member)
  #   3. A collaborator explicitly added to this project
  #   4. An admin
  #
  # Ordinary student group members are NOT in the list above, so a student
  # cannot view another student's assignment circuit through any web or API route
  # that calls authorize(@project, :check_view_access?).
  def check_view_access?
    project.project_access_type != "Private" ||
      (!user.nil? && project.author_id == user.id) ||
      (!user.nil? && !project.assignment_id.nil? &&
      ((project.assignment.group.primary_mentor_id == user.id) ||
      project.assignment.group.group_members.exists?(user_id: user.id, mentor: true))) ||
      (!user.nil? && Collaboration.exists?(project_id: project.id, user_id: user.id)) ||
      (!user.nil? && user.admin)
  end

  def check_direct_view_access?
    project.project_access_type == "Public" ||
      (project.project_submission == false && !user.nil? && project.author_id == user.id) ||
      (!user.nil? && Collaboration.exists?(project_id: project.id, user_id: user.id)) ||
      (!user.nil? && user.admin)
  end

  def edit_access?
    raise @simulator_exception unless user_access?

    true
  end

  def view_access?
    raise @simulator_exception unless check_view_access?

    true
  end

  def direct_view_access?
    raise @simulator_exception unless check_direct_view_access?

    true
  end

  def embed?
    raise @simulator_exception unless project.project_access_type != "Private"

    true
  end

  def create_fork?
    project.assignment_id.nil?
  end

  def submit?
    return false if user.nil? || project.author_id != user.id
    return false if project.assignment_id.nil?

    assignment = project.assignment
    assignment.status != "closed" &&
      assignment.deadline > Time.current &&
      !project.project_submission?
  end

  def unsubmit?
    return false if user.nil? || project.author_id != user.id
    return false if project.assignment_id.nil? || !project.project_submission?

    assignment = project.assignment
    assignment.allow_resubmit? &&
      assignment.status != "closed" &&
      assignment.deadline > Time.current
  end

  def author_access?
    (user.present? && user.admin?) || project.author_id == (user.present? && user.id)
  end
end
