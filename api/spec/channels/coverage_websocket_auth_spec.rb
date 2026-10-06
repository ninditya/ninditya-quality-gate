# frozen_string_literal: true

require 'rails_helper'

# The live coverage socket shows an interview as it happens: which skills the
# candidate has been probed on and how far each has got. The HTTP API limits
# that view to assessors; the socket has to as well.
RSpec.describe CoverageWebSocketMiddleware do
  subject(:middleware) { described_class.new(->(_env) { [404, {}, []] }) }

  let(:org)        { create(:organization) }
  let(:assessment) { create(:assessment, :with_skills, organization: org) }
  let(:session)    { create(:session, :active, assessment: assessment) }

  def connect_as(role, organization: org)
    middleware.send(:authenticate_assessor_by_token, token_for(organization, role: role), session.id.to_s)
  end

  it 'refuses a signed token whose role is not an assessor role [AC-SEC-06]' do
    %w[student user candidate].each do |role|
      found, error = connect_as(role)

      expect(found).to be_nil, "a '#{role}' token was allowed to watch the interview"
      expect(error).to eq('Not permitted')
    end
  end

  it 'lets an assessor of the same tenant watch [AC-SEC-06]' do
    %w[admin assessor].each do |role|
      found, error = connect_as(role)

      expect(error).to be_nil
      expect(found).to eq(session)
    end
  end

  it 'still refuses an assessor of another tenant' do
    found, error = connect_as('admin', organization: create(:organization))

    expect(found).to be_nil
    expect(error).to eq('Session not found')
  end
end
