# frozen_string_literal: true

require 'rails_helper'

# "The response said it worked" must mean the data changed. Each example pairs
# the HTTP answer with what is actually persisted afterwards.
RSpec.describe 'Write honesty', type: :request do
  let(:org)     { create(:organization) }
  let(:headers) { auth_headers(org) }

  describe 'DELETE /assessments/:id' do
    it 'does not claim success when the assessment still exists [AC-ASM-02]' do
      assessment = create(:assessment, organization: org)
      create(:session, assessment: assessment)

      delete "/api/v1/assessments/#{assessment.id}", headers: headers

      expect(Assessment.unscoped.exists?(assessment.id)).to be(true)
      expect(response).to have_http_status(:conflict)
      expect(response.body).not_to include('Assessment deleted')
    end

    it 'deletes an assessment that has no sessions' do
      assessment = create(:assessment, organization: org)

      delete "/api/v1/assessments/#{assessment.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(Assessment.unscoped.exists?(assessment.id)).to be(false)
    end
  end

  # The edit forms send the list of skills that remain on screen. A skill the
  # assessor removed is simply absent from that list.
  describe 'PUT with a skill removed in the edit form' do
    it 'removes the skill from the assessment [AC-ASM-01]' do
      assessment = create(:assessment, :with_skills, organization: org)
      keep, drop = assessment.assessment_skills.order(:display_order).first(2)
      remaining  = assessment.assessment_skills.where.not(id: drop.id).order(:display_order)

      put "/api/v1/assessments/#{assessment.id}",
          params: { assessment: { name: assessment.name, time_limit_min: 45,
                                  assessment_skills_attributes: remaining.each_with_index.map do |s, i|
                                    s.attributes.slice('id', 'skill_label', 'l1_anchor', 'l2_anchor', 'l3_anchor',
                                                       'l4_anchor', 'l5_anchor', 'expected_level')
                                     .merge('display_order' => i)
                                  end } },
          headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      labels = assessment.reload.assessment_skills.pluck(:skill_label)
      expect(labels).to include(keep.skill_label)
      expect(labels).not_to include(drop.skill_label)
      expect(json.dig('assessment', 'skills').map { |s| s['skill_label'] }).to match_array(labels)
    end

    it 'removes the skill from the vacancy [AC-VAC-01]' do
      vacancy = create(:vacancy, organization: org)
      keep = create(:vacancy_skill, vacancy: vacancy, skill_label: 'React / Frontend Development')
      create(:vacancy_skill, vacancy: vacancy, skill_label: 'Communication')

      put "/api/v1/vacancies/#{vacancy.id}",
          params: { vacancy: { role_title: vacancy.role_title,
                               vacancy_skills_attributes: [
                                 { id: keep.id, skill_label: keep.skill_label, expected_level: 4 }
                               ] } },
          headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(vacancy.reload.vacancy_skills.pluck(:skill_label, :expected_level))
        .to eq([['React / Frontend Development', 4]])
    end

    it 'leaves skills alone when the request does not mention them' do
      assessment = create(:assessment, :with_skills, organization: org)

      put "/api/v1/assessments/#{assessment.id}",
          params: { assessment: { name: 'Renamed' } }, headers: headers, as: :json

      expect(assessment.reload.assessment_skills.count).to eq(3)
    end
  end

  describe 'unknown routes' do
    it 'answers JSON 404, never an HTML error page [AC-API-01]' do
      get '/interview/some-token'

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq('application/json')
      expect(json).to include('error' => 'Route not found', 'status' => 404)
    end
  end
end
