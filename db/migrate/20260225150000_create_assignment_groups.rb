# frozen_string_literal: true

class CreateAssignmentGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :assignment_groups do |t|
      t.references :assignment, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true

      t.timestamps
    end

    add_index :assignment_groups, %i[assignment_id group_id], unique: true
  end
end
