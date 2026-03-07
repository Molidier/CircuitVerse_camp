# frozen_string_literal: true

class CreateAssignmentComments < ActiveRecord::Migration[7.0]
  def change
    create_table :assignment_comments do |t|
      t.references :assignment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end
    add_index :assignment_comments, [:assignment_id, :created_at]
  end
end
