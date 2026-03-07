# frozen_string_literal: true

class AddActivityTimestampsToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :started_at, :datetime
    add_column :projects, :submitted_at, :datetime
  end
end
