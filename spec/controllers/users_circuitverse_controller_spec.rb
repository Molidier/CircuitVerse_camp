# frozen_string_literal: true

require "rails_helper"

describe Users::CircuitverseController, type: :request do
  before do
    @user = FactoryBot.create(:user)
    sign_in @user
  end

  it "gets user projects" do
    get user_projects_path(id: @user.id)
    expect(response.status).to eq(200)
  end

  it "gets user profile" do
    get profile_path(id: @user.id)
    expect(response).to redirect_to(user_projects_path(id: @user.id))
    expect(response.status).to eq(301)
  end

  describe "#groups" do
    before do
      sign_out @user
    end

    context "user logged in is admin" do
      it "gets user groups" do
        sign_in FactoryBot.create(:user, admin: true)
        get user_groups_path(id: @user.id)
        expect(response.status).to eq(200)
      end
    end

    context "logged in user requests its own group" do
      it "gets user groups" do
        sign_in @user
        get user_groups_path(id: @user.id)
        expect(response.status).to eq(200)
      end
    end

    context "logged in user requests some other user's groups" do
      it "does not get groups" do
        sign_in FactoryBot.create(:user)
        get user_groups_path(id: @user.id)
        expect(response.body).to eq("You are not authorized to do the requested operation")
      end
    end
  end

  describe "#dashboard" do
    before do
      sign_out @user
      @mentor = FactoryBot.create(:user)
      @group  = FactoryBot.create(:group, primary_mentor: @mentor)
      FactoryBot.create(:group_member, user: @user, group: @group, mentor: false)
      @assignment = FactoryBot.create(:assignment, group: @group)
    end

    context "when the user views their own dashboard" do
      before { sign_in @user }

      it "returns 200" do
        get student_dashboard_path(id: @user.id)
        expect(response.status).to eq(200)
      end

      it "lists all groups the student belongs to" do
        get student_dashboard_path(id: @user.id)
        expect(response.body).to include(@group.name)
      end

      it "lists assignments within each group" do
        get student_dashboard_path(id: @user.id)
        expect(response.body).to include(@assignment.name)
      end

      it "shows Not Started when student hasn't created a project yet" do
        get student_dashboard_path(id: @user.id)
        expect(response.body).to include("Not started")
      end

      it "shows Started badge after the student starts the assignment" do
        FactoryBot.create(:project, assignment: @assignment, author: @user,
                                    started_at: 1.hour.ago)
        get student_dashboard_path(id: @user.id)
        expect(response.body).to include("Started")
      end

      it "shows Submitted badge after project_submission becomes true" do
        FactoryBot.create(:project, assignment: @assignment, author: @user,
                                    project_submission: true, submitted_at: 30.minutes.ago)
        get student_dashboard_path(id: @user.id)
        expect(response.body).to include("Submitted")
      end

      it "does NOT show groups where the student is a mentor (owns the group)" do
        mentor_group = FactoryBot.create(:group, primary_mentor: @user, name: "My Owned Group XYZ")
        get student_dashboard_path(id: @user.id)
        expect(response.body).not_to include("My Owned Group XYZ")
      end
    end

    context "when another user requests the dashboard" do
      it "is not authorized" do
        sign_in FactoryBot.create(:user)
        get student_dashboard_path(id: @user.id)
        expect(response.body).to eq("You are not authorized to do the requested operation")
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get student_dashboard_path(id: @user.id)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  it "gets edit profile" do
    get profile_edit_path(id: @user.id)
    expect(response.status).to eq(200)
  end

  it "updates user profile" do
    patch profile_update_path(@user), params: {
      id: @user.id,
      user: { name: "Jd", country: "IN", educational_institute: "MAIT" }
    }
    expect(response).to redirect_to(user_projects_path(id: @user.id))
    expect(@user.name).to eq("Jd")
    expect(@user.country).to eq("IN")
    expect(@user.educational_institute).to eq("MAIT")
  end

  it "remembers session redirect for short URLs" do
    get contribute_path
    expect(session[:user_return_to]).to eq("/contribute")
  end

  it "does not remember session redirect for long URLs" do
    get "/?x=#{'x' * 300}"
    expect(session[:user_return_to]).to eq("/")
  end
end
