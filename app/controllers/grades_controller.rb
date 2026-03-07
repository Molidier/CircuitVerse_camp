# frozen_string_literal: true

require "csv"

class GradesController < ApplicationController
  include ActionView::Helpers::SanitizeHelper

  before_action :authenticate_user!
  before_action :set_grade, only: %i[create destroy]
  before_action :set_assignment_for_import, only: %i[import]
  before_action :authorize_import, only: %i[import]

  def create
    @grade = @grade.presence || Grade.new(assignment_id: grade_params[:assignment_id])

    authorize @grade, :mentor?

    grade = sanitize grade_params[:grade].presence || @grade.grade
    remarks = sanitize grade_params[:remarks].presence || @grade.remarks

    @grade.project_id = grade_params[:project_id]
    @grade.grade = grade
    @grade.assignment_id = grade_params[:assignment_id]
    @grade.user_id = current_user.id
    @grade.remarks = remarks
    @grade.rubric_scores = grade_params[:rubric_scores].to_h if grade_params[:rubric_scores].present?

    if Flipper.enabled?(:lms_integration, current_user) && session[:is_lti]
      # pass grade back to the LMS if session is LTI
      project = Project.find(grade_params[:project_id])
      assignment = Assignment.find(grade_params[:assignment_id])

      # Only attempt LTI score submission if required parameters are present
      if session[:lis_outcome_service_url].present? && project.lis_result_sourced_id.present?
        score = grade.to_f / 100 # conversion to 0-0.100 scale as per IMS Global specification
        LtiScoreSubmission.new(
          assignment: assignment,
          lis_result_sourced_id: project.lis_result_sourced_id,
          score: score,
          lis_outcome_service_url: session[:lis_outcome_service_url]
        ).call # LTI score submission, see app/helpers/lti_helper.rb
      end
    end

    if @grade.save
      render json: { grade: @grade.grade, remarks: @grade.remarks, project_id: @grade.project_id }, status: :ok
      return
    end

    render json: { error: "Grade is invalid" },
           status: :bad_request
  end

  def destroy
    project_id = @grade&.project_id
    if @grade.present?
      authorize @grade, :mentor?
      @grade.destroy
    end

    render json: { project_id: project_id }, status: :ok
  end

  def to_csv
    assignment_id = params[:assignment_id].to_i
    respond_to do |format|
      format.csv do
        send_data Grade.to_csv(assignment_id),
                  filename: "#{Assignment.find(assignment_id).name} grades.csv"
      end
    end
  end

  def import
    file = params[:file]
    unless file.respond_to?(:read)
      redirect_back fallback_location: group_assignment_path(@assignment.groups.first, @assignment),
                    alert: t("grades.import.no_file")
      return
    end

    imported = 0
    errors = []
    csv = CSV.parse(file.read, headers: true)
    csv.each_with_index do |row, idx|
      email = row["email"]&.strip
      next if email.blank?

      user = User.find_by(email: email)
      unless user
        errors << t("grades.import.user_not_found", row: idx + 2, email: email)
        next
      end

      project = Project.find_by(author_id: user.id, assignment_id: @assignment.id)
      unless project
        errors << t("grades.import.no_submission", row: idx + 2, email: email)
        next
      end

      grade_value = row["grade"]&.strip
      grade_value = nil if grade_value.blank? || grade_value == "N.A"
      remarks = row["remarks"]&.strip
      remarks = nil if remarks.blank? || remarks == "N.A"

      record = Grade.find_or_initialize_by(project_id: project.id, assignment_id: @assignment.id)
      record.grade = grade_value.presence || record.grade
      record.remarks = remarks.presence || record.remarks
      record.user_id = current_user.id
      next if record.new_record? && record.grade.blank? # skip creating grade with no value
      if record.save
        imported += 1
      else
        errors << t("grades.import.validation_error", row: idx + 2, email: email, errors: record.errors.full_messages.join(", "))
      end
    end

    notice = t("grades.import.result", count: imported, total: csv.size)
    alert = errors.any? ? errors.first(5).join("; ") : nil
    redirect_back fallback_location: group_assignment_path(@assignment.groups.first, @assignment),
                  notice: notice,
                  alert: alert
  end

  private

    def grade_params
      params.expect(grade: [:project_id, :grade, :assignment_id, :remarks, { rubric_scores: {} }])
    end

    def set_grade
      @grade = Grade.find_by(project_id: grade_params[:project_id],
                             assignment_id: grade_params[:assignment_id])
    end

    def set_assignment_for_import
      @assignment = Assignment.find(params[:assignment_id])
    end

    def authorize_import
      authorize @assignment, :mentor_access?
    end
end
