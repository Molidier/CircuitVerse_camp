# frozen_string_literal: true

class AddTaToGroupMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :group_members, :ta, :boolean, default: false, null: false
  end
end
