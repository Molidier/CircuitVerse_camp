# frozen_string_literal: true

class AddAllowResubmitAndRubricToAssignments < ActiveRecord::Migration[7.2]
  def change
    add_column :assignments, :allow_resubmit, :boolean, default: false, null: false
    add_column :assignments, :rubric, :jsonb, default: [], null: false
  end
end
