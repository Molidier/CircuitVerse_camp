# frozen_string_literal: true

class AssignmentCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group_and_assignment
  before_action :authorize_mentor

  def create
    @comment = @assignment.assignment_comments.build(comment_params)
    @comment.user = current_user
    if @comment.save
      redirect_to group_assignment_path(@group, @assignment),
                  notice: t("assignment_comments.created")
    else
      redirect_to group_assignment_path(@group, @assignment),
                  alert: @comment.errors.full_messages.to_sentence
    end
  end

  private

  def set_group_and_assignment
    @group = Group.find(params[:group_id])
    @assignment = @group.assignments.find(params[:assignment_id])
  end

  def authorize_mentor
    authorize @assignment, :mentor_access?
  end

  def comment_params
    params.require(:assignment_comment).permit(:body)
  end
end
