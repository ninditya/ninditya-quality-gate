# frozen_string_literal: true

class PortfolioSkill < ApplicationRecord
  CONFIDENCE_LEVELS = %w[high medium low].freeze

  belongs_to :portfolio
  has_one :assessor_override, dependent: :destroy

  # Tenant ownership is inherited from the portfolio (see Portfolio.for_tenant).
  scope :for_tenant, lambda { |tenant_id|
    where(portfolio_id: Portfolio.for_tenant(tenant_id).select(:id))
  }

  validates :skill_label, presence: true
  # nil means "not assessed". It is never defaulted to a level.
  validates :ai_level, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :ai_confidence, inclusion: { in: CONFIDENCE_LEVELS }
  validates :competency_summary, presence: true

  def assessed?
    !ai_level.nil?
  end

  # evidence is stored as JSONB array of quote strings
  def evidence_quotes
    Array(evidence)
  end

  # "Quotes" the model offered that the candidate's transcript does not contain.
  def unverified_quotes
    Array(unverified_evidence)
  end
end
