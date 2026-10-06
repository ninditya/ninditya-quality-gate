# frozen_string_literal: true

require 'rails_helper'

# Portfolios, portfolio skills and fit/gap reports have no tenant_id column.
# They belong to a tenant only through their session, so a bare
# `Portfolio.find(params[:id])` in a controller is a cross-tenant read. That is
# the defect class behind AC-SEC-01 and AC-SEC-02; this guard catches the next
# instance when it is written, not when a client finds it.
RSpec.describe 'Tenant scoping guard' do
  TENANTLESS = %w[Portfolio PortfolioSkill FitGapReport AssessorOverride].freeze
  UNSCOPED_LOOKUP = /\b(#{TENANTLESS.join('|')})\s*\.\s*(find|find_by|find_by!|where|all|first|last|joins|includes|unscoped)\b/

  it 'reaches tenant-less tables only through a tenant scope [AC-SEC-04]' do
    offenders = Dir[Rails.root.join('app/controllers/**/*.rb')].flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next if line.strip.start_with?('#')

        "#{Pathname.new(file).relative_path_from(Rails.root)}:#{index + 1}: #{line.strip}" if line.match?(UNSCOPED_LOOKUP)
      end
    end

    expect(offenders).to be_empty, <<~MSG
      These lookups do not name a tenant. Use the model's `for_tenant(current_tenant_id)` scope:
      #{offenders.join("\n")}
    MSG
  end
end
