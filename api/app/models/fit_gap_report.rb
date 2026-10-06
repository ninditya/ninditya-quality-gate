# frozen_string_literal: true

class FitGapReport < ApplicationRecord
  FIT_RESULTS = %w[match gap exceed not_assessed].freeze

  belongs_to :portfolio
  belongs_to :vacancy

  validates :skill_comparisons, presence: true

  # The stored report for this pair, or nil when there is none worth showing.
  def self.current_for(portfolio, vacancy)
    report = find_by(portfolio: portfolio, vacancy: vacancy)
    report unless report&.stale?
  end

  # A report is a snapshot of two inputs: the vacancy's requirements and the
  # portfolio's ratings. Once either is newer than the report, the report
  # describes something that no longer exists and must not be shown.
  def stale?
    inputs_changed_at = [vacancy.updated_at, portfolio.generated_at].compact.max
    generated_at.nil? || (inputs_changed_at.present? && generated_at < inputs_changed_at)
  end
end
