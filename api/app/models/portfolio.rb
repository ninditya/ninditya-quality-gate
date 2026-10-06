# frozen_string_literal: true

class Portfolio < ApplicationRecord
  GENERATION_STATUSES = %w[pending generating complete failed].freeze

  belongs_to :session
  has_many :portfolio_skills, dependent: :destroy
  has_many :assessor_overrides, through: :portfolio_skills
  has_many :fit_gap_reports, dependent: :destroy

  # A portfolio has no tenant_id of its own: it belongs to a tenant through its
  # session. Anything that looks one up by id on behalf of a caller must go
  # through this scope. A nil tenant matches nothing.
  scope :for_tenant, lambda { |tenant_id|
    where(session_id: Session.unscoped.where(tenant_id: tenant_id).select(:id))
  }

  validates :generation_status, inclusion: { in: GENERATION_STATUSES }

  scope :complete,    -> { where(generation_status: 'complete') }
  scope :failed,      -> { where(generation_status: 'failed') }
  scope :generating,  -> { where(generation_status: 'generating') }

  def complete?    = generation_status == 'complete'
  def generating?  = generation_status == 'generating'
  def failed?      = generation_status == 'failed'
end
