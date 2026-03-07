# frozen_string_literal: true

class AssignmentsController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
  include SanitizeDescription

  before_action :authenticate_user!
  before_action :set_assignment, only: %i[show edit update destroy start reopen close duplicate]
  before_action :set_group
  before_action :check_access, only: %i[edit update destroy reopen close duplicate]
  before_action :sanitize_assignment_description, only: %i[show edit]
  after_action :check_reopening_status, only: [:update]
  after_action :allow_iframe_lti, only: %i[show], constraints: lambda {
    Flipper.enabled?(:lms_integration, current_user)
  }

  # GET /assignments
  # GET /assignments.json
  def index
    @assignments = Assignment.all
  end

  # GET /assignments/1
  # GET /assignments/1.json
  def show
    authorize @assignment
    @assignment = AssignmentDecorator.new(@assignment)

    if policy(@assignment).mentor_access?
      # keyed by author_id so the view can look up each student's project in O(1)
      @student_projects = @assignment.projects
                                     .includes(:grade, :author)
                                     .index_by(&:author_id)
      @students = @group.group_members.member.includes(:user).map(&:user)
    end
  end

  def start
    authorize @assignment
    use_template = params[:start_from] == "template" && @assignment.template_project_id.present?
    if use_template
      template = Project.find_by(id: @assignment.template_project_id)
      if template.present?
        begin
          @project = template.fork(current_user)
          @project.update!(
            name: "#{current_user.name}/#{@assignment.name}",
            assignment_id: @assignment.id,
            project_access_type: "Private",
            started_at: Time.current
          )
          redirect_to user_project_path(current_user, @project)
          return
        rescue StandardError
          # Fall through to blank project
        end
      end
    end
    @project = current_user.projects.new
    @project.name = "#{current_user.name}/#{@assignment.name}"
    @project.assignment_id = @assignment.id
    @project.project_access_type = "Private"
    @project.started_at = Time.current
    @project.build_project_datum
    @project.save
    redirect_to user_project_path(current_user, @project)
  end

  def duplicate
    authorize @assignment, :mentor_access?
    copy = @assignment.dup
    copy.assign_attributes(
      name: "Copy of #{@assignment.name}",
      deadline: 1.week.from_now,
      status: "open",
      group_id: @group.id
    )
    copy.skip_notification_callbacks = true
    copy.save!
    redirect_to edit_group_assignment_path(@group, copy),
                notice: t("assignments.duplicate.success")
  end

  # GET /assignments/new
  def new
    @assignment = Assignment.new(deadline: 1.week.from_now)
    authorize @assignment, :mentor_access?
    @mentor_projects_for_template = current_user.projects.where(assignment_id: nil).order(:name).limit(200)
  end

  # GET /assignments/1/edit
  def edit
    authorize @assignment
    if policy(@assignment).mentor_access?
      @mentor_projects_for_template = current_user.projects.where(assignment_id: nil).order(:name).limit(200)
      @groups_for_assignment = groups_current_user_can_assign_to
    end
  end

  def reopen
    authorize @assignment
    @assignment.status = "open"
    @assignment.deadline = 1.day.from_now
    @assignment.save

    redirect_to edit_group_assignment_path(@group, @assignment)
  end

  # Close assignment
  def close
    authorize @assignment
    @assignment.status = "closed"
    @assignment.deadline = Time.zone.now
    @assignment.save

    redirect_to group_assignment_path(@group, @assignment)
  end

  # POST /assignments
  # POST /assignments.json
  def create
    description = params["description"]

    if Flipper.enabled?(:lms_integration, current_user) && params["lms-integration-check"]
      lti_consumer_key = SecureRandom.hex(4)
      lti_shared_secret = SecureRandom.hex(4)
    end

    params = assignment_create_params
    # params[:deadline] = params[:deadline].to_time

    @assignment = Assignment.new(params)
    authorize @group, :mentor_access?

    @assignment.description = description
    @assignment.status = "open"
    @assignment.deadline = 1.year.from_now if @assignment.deadline.nil?

    if Flipper.enabled?(:lms_integration, current_user)
      @assignment.lti_consumer_key = lti_consumer_key
      @assignment.lti_shared_secret = lti_shared_secret
    end

    respond_to do |format|
      if @assignment.save
        @assignment.groups << @group unless @assignment.groups.include?(@group)
        format.html { redirect_to @group, notice: "Assignment was successfully created." }
        format.json { render :show, status: :created, location: @assignment }
      else
        @mentor_projects_for_template = current_user.projects.where(assignment_id: nil).order(:name).limit(200)
        format.html { render :new }
        format.json { render json: @assignment.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /assignments/1
  # PATCH/PUT /assignments/1.json
  def update
    description = params["description"]

    if Flipper.enabled?(:lms_integration, current_user) && params["lms-integration-check"]
      lti_consumer_key = @assignment.lti_consumer_key.presence || SecureRandom.hex(4)
      lti_shared_secret = @assignment.lti_shared_secret.presence || SecureRandom.hex(4)
    end

    if params[:assignment] && params[:assignment][:group_ids].present?
      allowed_ids = groups_current_user_can_assign_to.pluck(:id)
      requested = (Array(params[:assignment][:group_ids]).reject(&:blank?).map(&:to_i) + [@group.id]).uniq
      @assignment.group_ids = (requested & allowed_ids).presence || [@group.id]
    end

    params = assignment_update_params
    @assignment.description = description

    if Flipper.enabled?(:lms_integration, current_user)
      @assignment.lti_consumer_key = lti_consumer_key
      @assignment.lti_shared_secret = lti_shared_secret
    end
    # params[:deadline] = params[:deadline].to_time

    respond_to do |format|
      if @assignment.update(params)
        format.html { redirect_to @group, notice: "Assignment was successfully updated." }
        format.json { render :show, status: :ok }
      else
        @mentor_projects_for_template = current_user.projects.where(assignment_id: nil).order(:name).limit(200) if policy(@assignment).mentor_access?
        format.html { render :edit }
        format.json { render json: @assignment.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /assignments/1
  # DELETE /assignments/1.json
  def destroy
    @assignment.destroy
    respond_to do |format|
      format.html { redirect_to @group, notice: "Assignment was successfully deleted." }
      format.json { head :no_content }
    end
  end

  def allow_iframe_lti
    return unless session[:is_lti]

    response.headers["X-FRAME-OPTIONS"] = "ALLOW-FROM #{session[:lms_domain]}"
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_assignment
      @assignment = @group.assignments.find(params[:id])
    end

    def set_group
      @group = Group.find(params[:group_id])
    end

    def check_reopening_status
      @assignment.check_reopening_status
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def assignment_create_params
      p = params.expect(assignment: %i[name deadline description grading_scale
                                       restrictions feature_restrictions allow_resubmit rubric template_project_id])
      normalize_rubric_param(p)
    end

    def assignment_update_params
      p = params.expect(assignment: %i[name deadline description
                                       restrictions feature_restrictions allow_resubmit rubric template_project_id])
      normalize_rubric_param(p)
    end

    def groups_current_user_can_assign_to
      Group.where(primary_mentor_id: current_user.id)
           .or(Group.joins(:group_members).where(group_members: { user_id: current_user.id, mentor: true }))
           .or(Group.joins(:group_members).where(group_members: { user_id: current_user.id, ta: true }))
           .distinct.order(:name)
    end

    def normalize_rubric_param(params_hash)
      # Handle both flat (assignment attributes) and nested (params_hash[:assignment])
      attrs = params_hash[:assignment] || params_hash
      return params_hash unless attrs.respond_to?(:[])

      rubric = attrs[:rubric]
      attrs[:rubric] = parse_rubric(rubric) if rubric.present?
      params_hash
    end

    def parse_rubric(rubric)
      return rubric if rubric.is_a?(Array)

      JSON.parse(rubric.to_s)
    rescue JSON::ParserError
      []
    end

    def check_access
      authorize @assignment, :mentor_access?
    end

    def sanitize_assignment_description
      @assignment.description = sanitize_description(@assignment.description)
    end
end
