# frozen_string_literal: true

# Where a "quote" goes when the candidate never said it.
#
# The model is asked for quotes from the candidate and sometimes writes its
# own. Those used to be stored in `evidence` beside the real ones and shown as
# "Evidence from interview". They are kept, because dropping model output
# silently hides what the model did, but in a column of their own, so that
# nothing in `evidence` is anything other than the candidate's words.
class AddUnverifiedEvidenceToPortfolioSkills < ActiveRecord::Migration[7.0]
  def change
    add_column :portfolio_skills, :unverified_evidence, :jsonb, null: false, default: []
  end
end
