# frozen_string_literal: true

require 'rails_helper'

# The API half of the web/API seam. Each example produces a real response and
# compares its shape with the fixture the web suite renders. Rename or drop a
# field here and this goes red; the web suite goes red if the screen stops
# reading it.
RSpec.describe 'API contracts the web app depends on', type: :request do
  let(:org)        { create(:organization) }
  let(:headers)    { auth_headers(org) }
  let(:assessment) { create(:assessment, :with_skills, organization: org) }
  let(:session)    { create(:session, :ended, assessment: assessment) }
  let(:portfolio)  { create(:portfolio, session: session) }

  it 'POST /assessments/:id/sessions matches contracts/session_created.json [AC-API-02]' do
    post "/api/v1/assessments/#{assessment.id}/sessions",
         params: { session: { candidate_name: 'Ahmad Rizky' } }, headers: headers

    expect(shape_diff(contract('session_created'), json)).to eq([])
  end

  it 'GET /sessions/:id/portfolio matches contracts/portfolio.json [AC-API-02]' do
    rated = create(:portfolio_skill, portfolio: portfolio, skill_id: 'sk-eng-001')
    AssessorOverride.create!(portfolio_skill: rated, ai_level: 3, override_level: 4,
                             assessor_notes: 'Stronger than rated.', overridden_by: 1)

    get "/api/v1/sessions/#{session.id}/portfolio", headers: headers

    expect(response).to have_http_status(:ok)
    expect(shape_diff(contract('portfolio'), json)).to eq([])
  end

  it 'GET /portfolios/:id/fitgap/:vacancy_id matches contracts/fit_gap_report.json [AC-API-02]' do
    vacancy = create(:vacancy, organization: org)
    create(:portfolio_skill, portfolio: portfolio, skill_id: 'sk-eng-001')
    create(:vacancy_skill, vacancy: vacancy, skill_id: 'sk-eng-001')
    create(:vacancy_skill, vacancy: vacancy, skill_label: 'System Design', expected_level: 2)
    FitGap::Engine.new(portfolio: portfolio, vacancy: vacancy,
                       gemini_client: FakeGemini.new({ 'culture_narrative' => 'c', 'overall_narrative' => 'o' })).call

    get "/api/v1/portfolios/#{portfolio.id}/fitgap/#{vacancy.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(shape_diff(contract('fit_gap_report'), json)).to eq([])
  end
end
