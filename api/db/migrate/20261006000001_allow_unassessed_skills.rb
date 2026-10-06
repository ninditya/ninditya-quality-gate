# frozen_string_literal: true

# Lets the database say "this skill was not assessed".
#
# ai_level was NOT NULL, so a skill with no rating could not be stored. The
# generator worked around that by clamping the missing level to 1, which turned
# "we do not know" into "L1" in the portfolio, the fit/gap report and the PDF.
# NULL now means not assessed. The 1..5 check constraints already allow NULL.
#
# The override keeps the AI level it replaced, so it has to allow NULL too: an
# assessor may rate a skill the AI could not.
class AllowUnassessedSkills < ActiveRecord::Migration[7.0]
  def change
    change_column_null :portfolio_skills,   :ai_level, true
    change_column_null :assessor_overrides, :ai_level, true
  end
end
