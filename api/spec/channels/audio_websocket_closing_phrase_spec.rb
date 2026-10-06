# frozen_string_literal: true

require 'rails_helper'

# The middleware treats certain phrases in the AI's speech as "the AI has closed
# the interview" and schedules the session to end. Those phrases are also things
# an interviewer says in passing.
RSpec.describe AudioWebSocketMiddleware do
  subject(:middleware) { described_class.new(->(_env) { [404, {}, []] }) }

  let(:assessment) { create(:assessment, :with_skills, system_prompt: 'You are an assessor.') }
  let(:session)    { create(:session, :active, assessment: assessment) }
  let(:socket)     { instance_double(Faye::WebSocket, send: true, close: true) }
  let(:state)      { described_class::ConnectionState.new }
  let(:scheduled)  { [] }

  before do
    state.session = session
    state.gemini_client = instance_double(Gemini::LiveClient, inject_context: true)
    assessment.assessment_skills.each do |skill|
      create(:coverage_map, session: session, skill_label: skill.skill_label, state: 'not_yet')
    end
    allow(EM).to receive(:add_timer) { |_delay, &blk| scheduled << blk }
    allow(Thread).to receive(:new) { |&blk| blk.call }
  end

  def ai_says(text)
    middleware.send(:build_on_output_transcription, socket, state, session).call(text)
  end

  it 'keeps the interview going when the AI is merely being polite [AC-SES-05]' do
    ai_says('Good luck with that migration. How did you plan the rollback?')

    expect(state.coverage_pending).to be_falsy
    expect(scheduled).to be_empty
  end

  it 'treats a closing phrase as the close when every configured skill is covered [AC-SES-05]' do
    session.coverage_maps.update_all(state: 'covered', probe_count: 3)

    ai_says('That covers everything. Thank you for your time today.')

    expect(state.coverage_pending).to be(true)
    expect(scheduled).not_to be_empty
  end

  it 'treats a closing phrase as the close after the one-minute time warning [AC-SES-05]' do
    state.sent_time_warnings.add(:warn_60)

    ai_says('We are out of time. Thank you for your time today.')

    expect(state.coverage_pending).to be(true)
  end

  it 'still treats a closing phrase as the close once wrap-up was signalled' do
    state.wrap_up_injected = true

    ai_says('Thank you for your time today. Goodbye.')

    expect(state.coverage_pending).to be(true)
    expect(scheduled).not_to be_empty
  end
end
