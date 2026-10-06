# frozen_string_literal: true

require 'rails_helper'

# The portfolio is what a hiring decision is read from. The model's output is
# untrusted input: every example feeds it something plausible-but-wrong and
# checks what ends up persisted, not what a screen would show.
RSpec.describe Portfolios::Generator do
  let(:assessment) { create(:assessment, :with_skills) }
  let(:session)    { create(:session, :ended, assessment: assessment) }

  let(:react)  { 'React / Frontend Development' }
  let(:comms)  { 'Communication' }
  let(:design) { 'System Design' }

  before do
    create(:coverage_map, session: session, skill_id: 'sk-eng-001', skill_label: react,
                          state: 'covered', probe_count: 5)
    create(:coverage_map, session: session, skill_label: comms, state: 'initiated', probe_count: 1)
    create(:coverage_map, session: session, skill_label: design, state: 'not_yet', probe_count: 0)
    create(:transcript_turn, session: session, turn_number: 1, speaker: 'ai',
                             text: 'Tell me about a hard frontend project.')
    create(:transcript_turn, session: session, turn_number: 2, speaker: 'candidate',
                             text: 'We moved real-time data into local component state with useRef.')
  end

  def model_skill(label, level:, confidence: 'high', skill_id: nil)
    { 'skill_id' => skill_id, 'skill_label' => label, 'level' => level, 'confidence' => confidence,
      'evidence' => ['We moved real-time data into local component state with useRef.'],
      'competency_summary' => "Summary for #{label}." }
  end

  def generate(response)
    described_class.new(session: session, gemini_client: FakeGemini.new(response)).call
  end

  def stored(label)
    session.reload.portfolio.portfolio_skills.find_by(skill_label: label)
  end

  it 'never turns a skill the model could not rate into L1 [AC-PF-01]' do
    generate('configured_skills' => [
               model_skill(react, level: 3, skill_id: 'sk-eng-001'),
               model_skill(comms, level: 2),
               model_skill(design, level: nil, confidence: 'low')
             ])

    expect(stored(design)).to be_present
    expect(stored(design).ai_level).to be_nil
  end

  it 'does not rate a skill that was never discussed, whatever the model says [AC-PF-01]' do
    generate('configured_skills' => [
               model_skill(react, level: 3, skill_id: 'sk-eng-001'),
               model_skill(comms, level: 2),
               model_skill(design, level: 4)
             ])

    expect(stored(design).ai_level).to be_nil
  end

  it 'keeps a configured skill the model left out, marked as not assessed [AC-PF-02]' do
    generate('configured_skills' => [model_skill(react, level: 3, skill_id: 'sk-eng-001')])

    labels = session.reload.portfolio.portfolio_skills.where(is_discovered: false).pluck(:skill_label)
    expect(labels).to contain_exactly(react, comms, design)
    expect(stored(comms).ai_level).to be_nil
  end

  it 'derives confidence from coverage, not from the model [AC-PF-03]' do
    generate('configured_skills' => [
               model_skill(react, level: 3, confidence: 'low', skill_id: 'sk-eng-001'),
               model_skill(comms, level: 2, confidence: 'high'),
               model_skill(design, level: nil, confidence: 'high')
             ])

    expect(stored(react).ai_confidence).to eq('high')  # covered, 5 probes
    expect(stored(comms).ai_confidence).to eq('low')   # initiated, 1 probe
  end

  it 'treats a level outside L1-L5 as not assessed rather than clamping it [AC-PF-01]' do
    generate('configured_skills' => [
               model_skill(react, level: 9, skill_id: 'sk-eng-001'),
               model_skill(comms, level: 0)
             ])

    expect(stored(react).ai_level).to be_nil
    expect(stored(comms).ai_level).to be_nil
  end

  it 'keeps a discovered skill only when the coverage map tracked it [AC-PF-02]' do
    create(:coverage_map, session: session, skill_label: 'Micro-frontend Architecture',
                          is_discovered: true, state: 'partial', probe_count: 2)

    generate('configured_skills' => [model_skill(react, level: 3, skill_id: 'sk-eng-001')],
             'discovered_skills' => [
               model_skill('Micro-frontend Architecture', level: 2, confidence: 'high'),
               model_skill('Kubernetes', level: 4, confidence: 'high')
             ])

    discovered = session.reload.portfolio.portfolio_skills.where(is_discovered: true)
    expect(discovered.pluck(:skill_label, :ai_level, :ai_confidence))
      .to eq([['Micro-frontend Architecture', 2, 'medium']])
  end

  it 'keeps the previous ratings and overrides when regeneration fails [AC-PF-04]' do
    portfolio = create(:portfolio, session: session, generation_status: 'failed')
    rated     = create(:portfolio_skill, portfolio: portfolio, skill_label: react, ai_level: 3)
    AssessorOverride.create!(portfolio_skill: rated, ai_level: 3, override_level: 4, overridden_by: 1)

    broken = { 'configured_skills' => [
      model_skill(react, level: 3, skill_id: 'sk-eng-001'),
      model_skill(comms, level: 2).merge('competency_summary' => nil) # violates NOT NULL
    ] }

    expect { generate(broken) }.to raise_error(ActiveRecord::RecordInvalid)

    portfolio.reload
    expect(portfolio.generation_status).to eq('failed')
    expect(portfolio.portfolio_skills.pluck(:skill_label)).to eq([react])
    expect(AssessorOverride.where(portfolio_skill: rated)).to exist
  end

  it 'does not ask the model to rate an interview with no candidate speech [AC-PF-05]' do
    session.transcript_turns.where(speaker: 'candidate').destroy_all
    gemini = FakeGemini.new({ 'configured_skills' => [model_skill(react, level: 3, skill_id: 'sk-eng-001')] })

    described_class.new(session: session, gemini_client: gemini).call

    expect(gemini.prompts).to be_empty
    expect(session.reload.portfolio.portfolio_skills.pluck(:ai_level)).to all(be_nil)
  end
end
