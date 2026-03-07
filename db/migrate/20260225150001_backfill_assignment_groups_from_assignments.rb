# frozen_string_literal: true

class BackfillAssignmentGroupsFromAssignments < ActiveRecord::Migration[7.0]
  def up
    return unless column_exists?(:assignments, :group_id)

    say_with_time "backfilling assignment_groups" do
      safety_assured do
        insert_sql = <<-SQL.squish
          INSERT INTO assignment_groups (assignment_id, group_id, created_at, updated_at)
          SELECT a.id, a.group_id, a.created_at, a.updated_at FROM assignments a
          WHERE a.group_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM assignment_groups ag WHERE ag.assignment_id = a.id AND ag.group_id = a.group_id
          )
        SQL
        execute insert_sql
      end
    end
  end

  def down
    # no-op
  end
end
