# frozen_string_literal: true

require 'rails_helper'

# The path a real interview takes: invite -> candidate joins -> session ends.
RSpec.describe 'Session lifecycle', type: :request do
  let(:org)        { create(:organization) }
  let(:assessment) { create(:assessment, :with_skills, organization: org) }
  let(:headers)    { auth_headers(org) }

  describe 'invite link' do
    it 'points the candidate at the web app, not the API host [AC-INV-01]' do
      post "/api/v1/assessments/#{assessment.id}/sessions",
           params: { session: { candidate_name: 'Ahmad Rizky' } }, headers: headers

      expect(response).to have_http_status(:created)
      token = json.dig('session', 'invite_token')
      expect(json['invite_url']).to eq("#{ENV.fetch('WEB_BASE_URL')}/interview/#{token}")
      expect(json.dig('session', 'invite_url')).to eq(json['invite_url'])
    end
  end

  describe 'POST /sessions/:token/audio_complete (no login, invite token only)' do
    it 'does not end an interview that never started [AC-SES-01]' do
      session = create(:session, assessment: assessment)

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(session.reload.status).to eq('pending')
      expect(session.portfolio).to be_nil
      expect(PortfolioGeneratorWorker.jobs).to be_empty
      expect(response).to have_http_status(:conflict)
    end

    it 'records all_covered only when every configured skill really is covered [AC-SES-02]' do
      session = create(:session, :active, assessment: assessment)
      create(:coverage_map, session: session, skill_label: 'React / Frontend Development',
                            state: 'covered', probe_count: 3)
      create(:coverage_map, session: session, skill_label: 'Communication', state: 'not_yet')

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(session.reload.status).to eq('ended')
      expect(session.end_reason).not_to eq('all_covered')
    end

    it 'records all_covered when coverage is complete [AC-SES-02]' do
      session = create(:session, :active, assessment: assessment)
      assessment.assessment_skills.each do |skill|
        create(:coverage_map, session: session, skill_label: skill.skill_label,
                              state: 'covered', probe_count: 3)
      end

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(session.reload.end_reason).to eq('all_covered')
    end

    it 'records time_ceiling when the interview is wrapping up on time, not on coverage [AC-SES-02]' do
      session = create(:session, :active, assessment: assessment, started_at: 44.minutes.ago - 30.seconds)
      create(:coverage_map, session: session, skill_label: 'Communication', state: 'partial', probe_count: 2)

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(session.reload).to have_attributes(status: 'ended', end_reason: 'time_ceiling')
    end

    it 'does not count discovered skills towards all_covered [AC-SES-02]' do
      session = create(:session, :active, assessment: assessment)
      assessment.assessment_skills.each do |skill|
        create(:coverage_map, session: session, skill_label: skill.skill_label, state: 'covered', probe_count: 3)
      end
      create(:coverage_map, session: session, skill_label: 'Kubernetes', is_discovered: true, state: 'initiated')

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(session.reload.end_reason).to eq('all_covered')
    end
  end

  describe 'GET /sessions/:id/portfolio' do
    it 'does not report "generating" for a session that has no portfolio [AC-PF-06]' do
      session = create(:session, :active, assessment: assessment)

      get "/api/v1/sessions/#{session.id}/portfolio", headers: headers

      expect(response).not_to have_http_status(:accepted)
      expect(json['status']).to eq('not_available')
    end

    it 'still reports "generating" while a portfolio is being generated' do
      session = create(:session, :ended, assessment: assessment)
      create(:portfolio, session: session, generation_status: 'generating', generated_at: nil)

      get "/api/v1/sessions/#{session.id}/portfolio", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(json['status']).to eq('generating')
    end
  end
end
