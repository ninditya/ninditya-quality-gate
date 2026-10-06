# frozen_string_literal: true

require 'rails_helper'

# One tenant must never read or change another tenant's candidate data.
# Ids are sequential integers, so "the id is hard to guess" is not a control.
RSpec.describe 'Tenant isolation', type: :request do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }

  let(:assessment_a) { create(:assessment, :with_skills, organization: org_a) }
  let(:session_a)    { create(:session, :ended, assessment: assessment_a) }
  let(:portfolio_a)  { create(:portfolio, session: session_a) }
  let!(:skill_a)     { create(:portfolio_skill, portfolio: portfolio_a, ai_level: 3) }

  let(:vacancy_a) { create(:vacancy, organization: org_a) }
  let(:vacancy_b) { create(:vacancy, organization: org_b) }

  let(:intruder) { auth_headers(org_b) }

  it 'does not export another tenant portfolio [AC-SEC-01]' do
    get "/api/v1/portfolios/#{portfolio_a.id}/export", params: { format: 'json' }, headers: intruder

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(skill_a.competency_summary)
  end

  it 'does not run a fit/gap on another tenant portfolio [AC-SEC-01]' do
    create(:vacancy_skill, vacancy: vacancy_b)

    post "/api/v1/portfolios/#{portfolio_a.id}/fitgap",
         params: { fitgap: { vacancy_id: vacancy_b.id } }, headers: intruder

    expect(response).to have_http_status(:not_found)
    expect(FitGapGeneratorWorker.jobs).to be_empty
  end

  it 'does not show another tenant fit/gap report [AC-SEC-01]' do
    FitGapReport.create!(portfolio: portfolio_a, vacancy: vacancy_a,
                         skill_comparisons: [{ skill_label: 'React', candidate_level: 3 }])

    get "/api/v1/portfolios/#{portfolio_a.id}/fitgap/#{vacancy_a.id}", headers: intruder

    expect(response).to have_http_status(:not_found)
  end

  it 'does not let another tenant override a rating [AC-SEC-02]' do
    expect do
      post "/api/v1/portfolio_skills/#{skill_a.id}/override",
           params: { override: { override_level: 5, assessor_notes: 'not my candidate' } },
           headers: intruder
    end.not_to change(AssessorOverride, :count)

    expect(response).to have_http_status(:not_found)
  end

  it 'still serves the owning tenant' do
    get "/api/v1/portfolios/#{portfolio_a.id}/export", params: { format: 'json' }, headers: auth_headers(org_a)

    expect(response).to have_http_status(:ok)
  end

  describe 'login' do
    let!(:user_a) { create(:user, email: 'dimas@example.test') }

    before do
      org_a
      org_b
      # A user belongs to exactly one organization. The column does not exist
      # before the fix, which is the defect: nothing ties a login to a tenant.
      user_a.update_column(:organization_id, org_a.id) if User.column_names.include?('organization_id')
    end

    it 'never issues a token for a tenant the caller merely names in a header [AC-SEC-03]' do
      post '/api/v1/auth/login',
           params: { email: user_a.email, password: 'correct-horse-battery' },
           headers: { 'X-Tenant-Scheme' => org_b.scheme }

      token_scheme = response.successful? ? JsonWebToken.decode(json['token'])[:scheme] : nil
      expect(token_scheme).not_to eq(org_b.scheme)
    end

    it 'issues a token for the organization the user belongs to [AC-SEC-03]' do
      post '/api/v1/auth/login', params: { email: user_a.email, password: 'correct-horse-battery' }

      expect(response).to have_http_status(:ok)
      expect(JsonWebToken.decode(json['token'])[:scheme]).to eq(org_a.scheme)
    end
  end
end
