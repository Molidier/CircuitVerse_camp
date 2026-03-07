# frozen_string_literal: true

class AddRubricScoresToGrades < ActiveRecord::Migration[7.2]
  def change
    add_column :grades, :rubric_scores, :jsonb, default: {}, null: false
  end
end
