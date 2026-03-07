# frozen_string_literal: true

class AddTemplateProjectForeignKeyToAssignments < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_foreign_key :assignments, :projects,
                    column: :template_project_id,
                    validate: false
    validate_foreign_key :assignments, :projects, column: :template_project_id
  end
end
