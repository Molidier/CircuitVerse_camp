# frozen_string_literal: true

class AddTimeSpentSecondsToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :time_spent_seconds, :integer, default: 0, null: false
  end
end
