# frozen_string_literal: true

class VacancySkill < ApplicationRecord
  # touch: adding, changing or removing a requirement changes the vacancy. A
  # fit/gap report compares its own age with vacancy.updated_at to know whether
  # it still describes the current requirements (FitGapReport#stale?).
  belongs_to :vacancy, touch: true

  validates :skill_label, presence: true
  validates :expected_level, numericality: { only_integer: true, in: 1..5 }
end
