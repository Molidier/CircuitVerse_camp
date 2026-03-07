# frozen_string_literal: true

class RemoveGroupIdFromAssignments < ActiveRecord::Migration[7.0]
  def up
    return unless column_exists?(:assignments, :group_id)

    remove_foreign_key :assignments, :groups, if_exists: true
    safety_assured { remove_column :assignments, :group_id }
  end

  def down
    add_reference :assignments, :group, foreign_key: true
    execute <<-SQL.squish
      UPDATE assignments a SET group_id = (
        SELECT group_id FROM assignment_groups ag WHERE ag.assignment_id = a.id LIMIT 1
      )
    SQL
  end
end
