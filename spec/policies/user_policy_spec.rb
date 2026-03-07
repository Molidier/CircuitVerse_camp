# frozen_string_literal: true

require "rails_helper"

describe UserPolicy do
  subject { described_class.new(user, requested_user) }

  before do
    @user = FactoryBot.create(:user)
  end

  describe "#groups" do
    let(:user) { @user }

    context "user is same as requested_user" do
      let(:requested_user) { @user }

      it { is_expected.to permit(:groups) }
    end

    context "user is admin" do
      let(:requested_user) { @user }
      let(:user) { FactoryBot.create(:user, admin: true) }

      it { is_expected.to permit(:groups) }
    end

    context "user is not same as requested user" do
      let(:requested_user) { FactoryBot.create(:user) }

      it { is_expected.not_to permit(:groups) }
    end
  end

  describe "#dashboard" do
    context "user is same as requested_user" do
      let(:user)           { @user }
      let(:requested_user) { @user }

      it { is_expected.to permit(:dashboard) }
    end

    context "user is an admin viewing another user's dashboard" do
      let(:user)           { FactoryBot.create(:user, admin: true) }
      let(:requested_user) { @user }

      it { is_expected.to permit(:dashboard) }
    end

    context "user is a different non-admin user" do
      let(:user)           { FactoryBot.create(:user) }
      let(:requested_user) { @user }

      it { is_expected.not_to permit(:dashboard) }
    end
  end
end
