# frozen_string_literal: true

class Session < ApplicationRecord
  include TenantScoped

  STATUSES   = %w[pending active ended failed].freeze
  END_REASONS = %w[manual_candidate manual_assessor all_covered time_ceiling error].freeze

  belongs_to :assessment
  has_many :transcript_turns, dependent: :destroy
  has_many :coverage_maps, dependent: :destroy
  has_one  :portfolio, dependent: :destroy

  validates :invite_token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true

  before_validation :generate_invite_token, on: :create

  scope :active,  -> { where(status: 'active') }
  scope :pending, -> { where(status: 'pending') }
  scope :ended,   -> { where(status: 'ended') }

  def active?  = status == 'active'
  def ended?   = status == 'ended'
  def pending? = status == 'pending'

  # The link a candidate opens. The interview page is served by the web app, so
  # this is built from the web app's public URL, never from the API's own.
  def invite_url
    "#{self.class.web_base_url}/interview/#{invite_token}"
  end

  # False once a turn is known to be missing: a write that failed for good, or
  # a hole in the numbering. Turn numbers are handed out in order as people
  # speak, so a hole is a turn that was spoken and never stored.
  def transcript_complete?
    return false if transcript_incomplete

    numbers = transcript_turns.pluck(:turn_number)
    numbers.empty? || numbers.size == numbers.max - numbers.min + 1
  end

  def self.web_base_url
    ENV.fetch('WEB_BASE_URL', 'http://localhost:5173').chomp('/')
  end

  private

  def generate_invite_token
    self.invite_token ||= SecureRandom.hex(32)
  end
end
