# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Fit/gap report', type: :request do
  let(:org)        { create(:organization) }
  let(:headers)    { auth_headers(org) }
  let(:assessment) { create(:assessment, :with_skills, organization: org) }
  let(:session)    { create(:session, :ended, assessment: assessment) }
  let(:portfolio)  { create(:portfolio, session: session) }
  let(:vacancy)    { create(:vacancy, organization: org) }

  let!(:react)    { create(:portfolio_skill, portfolio: portfolio, skill_label: 'React / Frontend Development', ai_level: 3) }
  let!(:react_rq) { create(:vacancy_skill, vacancy: vacancy, skill_label: 'React / Frontend Development', expected_level: 3) }

  def run_engine
    FitGap::Engine.new(portfolio: portfolio, vacancy: vacancy,
                       gemini_client: FakeGemini.new({ 'culture_narrative' => 'c', 'overall_narrative' => 'o' })).call
  end

  def comparison(report, label)
    report.skill_comparisons.find { |c| c['skill_label'] == label }
  end

  it 'compares by rule: match, gap and exceed [AC-FG-01]' do
    create(:portfolio_skill, portfolio: portfolio, skill_label: 'Communication', ai_level: 2)
    create(:portfolio_skill, portfolio: portfolio, skill_label: 'System Design', ai_level: 3)
    create(:vacancy_skill, vacancy: vacancy, skill_label: 'Communication', expected_level: 3)
    create(:vacancy_skill, vacancy: vacancy, skill_label: 'System Design', expected_level: 2)

    report = run_engine

    expect(comparison(report, 'React / Frontend Development')).to include('result' => 'match', 'delta' => 0)
    expect(comparison(report, 'Communication')).to include('result' => 'gap', 'delta' => -1)
    expect(comparison(report, 'System Design')).to include('result' => 'exceed', 'delta' => 1)
  end

  it 'reports an unrated skill as not assessed, never as a gap [AC-FG-02]' do
    unrated = build(:portfolio_skill, portfolio: portfolio, skill_label: 'Communication', ai_level: nil)
    unrated.save!(validate: false) if PortfolioSkill.columns_hash['ai_level'].null
    create(:vacancy_skill, vacancy: vacancy, skill_label: 'Communication', expected_level: 3)

    report = run_engine

    expect(PortfolioSkill.where(portfolio: portfolio, skill_label: 'Communication')).to exist
    expect(comparison(report, 'Communication')).to include('result' => 'not_assessed', 'candidate_level' => nil)
  end

  it 'marks a level that came from a human override [AC-FG-03]' do
    AssessorOverride.create!(portfolio_skill: react, ai_level: 3, override_level: 4, overridden_by: 1)

    report = run_engine

    expect(comparison(report, 'React / Frontend Development'))
      .to include('candidate_level' => 4, 'result' => 'exceed', 'is_override' => true)
  end

  it 'does not serve a report computed against requirements that have since changed [AC-FG-04]' do
    run_engine
    travel_forward = 1.minute.from_now

    Timecop.freeze(travel_forward) do
      put "/api/v1/vacancies/#{vacancy.id}",
          params: { vacancy: { role_title: vacancy.role_title,
                               vacancy_skills_attributes: [{ id: react_rq.id, skill_label: react_rq.skill_label,
                                                             expected_level: 5 }] } },
          headers: headers, as: :json
      expect(response).to have_http_status(:ok)

      post "/api/v1/portfolios/#{portfolio.id}/fitgap",
           params: { fitgap: { vacancy_id: vacancy.id } }, headers: headers, as: :json
    end

    served = response.status == 200 ? json.dig('report', 'skill_comparisons', 0, 'expected_level') : nil
    expect(served).not_to eq(3), 'served the report computed against the old requirement (L3) after it changed to L5'
    expect(response).to have_http_status(:accepted)
    expect(FitGapGeneratorWorker.jobs.size).to eq(1)
  end
end
