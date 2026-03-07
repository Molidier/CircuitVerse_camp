# frozen_string_literal: true

class AddTemplateProjectIdToAssignments < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_reference :assignments, :template_project,
                  foreign_key: false,
                  index: { algorithm: :concurrently }
  end
end
