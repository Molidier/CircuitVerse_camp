# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  before do
    @user = FactoryBot.create(:user)
    group = FactoryBot.create(:group, primary_mentor: @user)
    @assignment = FactoryBot.create(:assignment, group: group)
  end

  describe "associations" do
    it { is_expected.to belong_to(:author) }
    it { is_expected.to belong_to(:assignment).optional }
    it { is_expected.to belong_to(:forked_project).optional }
    it { is_expected.to have_many(:forks) }
    it { is_expected.to have_many(:stars) }
    it { is_expected.to have_many(:collaborations) }
    it { is_expected.to have_many(:collaborators) }
    it { is_expected.to have_one(:featured_circuit) }
    it { is_expected.to have_many(:noticed_notifications) }
    it { is_expected.to have_one(:contest_winner) }
    it { is_expected.to have_many(:submissions) }
  end

  describe "validity" do
    it "doesn't validate with public access type" do
      project = FactoryBot.build(:project, assignment: @assignment, author: @user)
      expect(project).to be_valid
      project.project_access_type = "Public"
      expect(project).to be_invalid
    end

    it "doesn't allow profanities in description" do
      project = FactoryBot.build(:project, assignment: @assignment, author: @user)
      expect(project).to be_valid
      project.description = "Ass"
      expect(project).to be_invalid
    end
  end

  describe "public methods" do
    context "project submission is false" do
      before do
        @project = FactoryBot.create(
          :project,
          assignment: @assignment,
          author: @user,
          project_submission: false
        )
      end

      describe "#send_mail" do
        it "sends new project mail" do
          expect do
            @project.send_mail
          end.to have_enqueued_job.on_queue("mailers")
        end
      end
    end

    context "project submission is true" do
      before do
        @project = FactoryBot.create(
          :project,
          assignment: @assignment,
          author: @user,
          project_submission: true
        )
      end

      describe "#send_mail" do
        it "doesn't send new project mail" do
          expect do
            @project.send_mail
          end.not_to have_enqueued_job.on_queue("mailers")
        end
      end
    end

    describe "#increase_views" do
      before do
        @project = FactoryBot.build(:project, assignment: @assignment, author: @user)
        @viewer = FactoryBot.create(:user)
      end

      it "increases the number of views" do
        expect do
          @project.increase_views(@viewer)
        end.to change { @project.view }.by(1)
      end
    end

    describe "#check_and_remove_featured" do
      before do
        @project = FactoryBot.create(:project, author: @user, project_access_type: "Public")
        FactoryBot.create(:featured_circuit, project: @project)
      end

      it "removes featured project if project access is not public" do
        expect do
          @project.project_access_type = "Private"
          @project.save
        end.to change(FeaturedCircuit, :count).by(-1)
      end
    end
  end

  describe "#submission_status" do
    let(:project) { FactoryBot.create(:project, assignment: @assignment, author: @user) }

    context "when no grade and not submitted" do
      it "returns :started" do
        expect(project.submission_status).to eq(:started)
      end
    end

    context "when project_submission is true but no grade" do
      before { project.update_columns(project_submission: true) }

      it "returns :submitted" do
        expect(project.submission_status).to eq(:submitted)
      end
    end

    context "when a grade exists" do
      before do
        # assignment must have a grading scale for Grade validation to pass
        graded_assignment = FactoryBot.create(:assignment,
                                              group: FactoryBot.create(:group, primary_mentor: @user),
                                              grading_scale: :custom)
        graded_project = FactoryBot.create(:project, assignment: graded_assignment, author: @user)
        graded_project.update_columns(project_submission: true)
        FactoryBot.create(:grade, project: graded_project, assignment: graded_assignment,
                                  grader: @user, grade: "A+")
        @graded_project = graded_project
      end

      it "returns :graded" do
        expect(@graded_project.reload.submission_status).to eq(:graded)
      end
    end
  end

  describe "submitted_at callback" do
    let(:project) { FactoryBot.create(:project, assignment: @assignment, author: @user) }

    it "is nil before submission" do
      expect(project.submitted_at).to be_nil
    end

    it "is stamped when project_submission flips to true" do
      expect {
        project.update!(project_submission: true)
      }.to change { project.reload.submitted_at }.from(nil)
    end

    it "is not overwritten on subsequent saves" do
      project.update!(project_submission: true)
      original_time = project.submitted_at
      travel_to 1.hour.from_now do
        project.update!(description: "updated")
        expect(project.reload.submitted_at).to be_within(1.second).of(original_time)
      end
    end
  end
end
