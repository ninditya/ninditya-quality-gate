# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Smoke', type: :request do
  it 'boots and answers the health check' do
    get '/health'
    expect(response).to have_http_status(:ok)
  end

  it 'rejects an unauthenticated assessor request' do
    org = create(:organization)
    get '/api/v1/assessments', headers: { 'X-Tenant-Scheme' => org.scheme }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists only the caller tenant assessments' do
    mine   = create(:assessment, name: 'Mine')
    create(:assessment, name: 'Theirs')
    org = Organization.find(mine.tenant_id)

    get '/api/v1/assessments', headers: auth_headers(org)

    expect(response).to have_http_status(:ok)
    expect(json['assessments'].map { |a| a['name'] }).to eq(['Mine'])
  end
end
