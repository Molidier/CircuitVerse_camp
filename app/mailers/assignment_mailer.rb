# frozen_string_literal: true

class AssignmentMailer < ApplicationMailer
  def new_assignment_email(user, assignment)
    return if user.opted_out?

    @assignment = assignment
    @user = user
    mail(to: [@user.email],
         subject: "New Assignment in #{@assignment.groups.map(&:name).join(", ")}")
  end

  def update_assignment_email(user, assignment)
    return if user.opted_out?

    @assignment = assignment
    @user = user
    mail(to: [@user.email],
         subject: "Assignment Updated in #{@assignment.groups.map(&:name).join(", ")}")
  end
end
