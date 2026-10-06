# frozen_string_literal: true

require 'rails_helper'

# "Covered" drives three things: the interview ending as "all skills covered",
# HIGH confidence on the rating, and what the assessor watching live believes.
# PRD-01 section 4 gives one way to get there: the analyzer judging that the
# evidence is enough. The analyzer itself is replaced here; the question is what
# the worker does with its answer.
RSpec.describe CoverageAnalyzerWorker do
  let(:assessment) { create(:assessment, :with_skills) }
  let(:session)    { create(:session, :active, assessment: assessment) }

  let!(:react) do
    create(:coverage_map, session: session, skill_label: 'React / Frontend Development',
                          state: 'partial', probe_count: 6)
  end
  let!(:comms) do
    create(:coverage_map, session: session, skill_label: 'Communication', state: 'partial', probe_count: 2)
  end

  def analyzer_reports(updates)
    analyzer = instance_double(Coverage::Analyzer, call: { skill_updates: updates, discovered_skills: [] })
    allow(Coverage::Analyzer).to receive(:new).and_return(analyzer)
  end

  it 'leaves a much-probed skill partial when the analyzer did not judge it covered [AC-COV-01]' do
    analyzer_reports([]) # the conversation has moved on; nothing is said about React

    described_class.new.perform(session.id, 12)

    expect(react.reload.state).to eq('partial')
    expect(Sessions::EndReason.all_configured_covered?(session)).to be(false)
  end

  it 'marks a skill covered when the analyzer says so, and only that skill [AC-COV-01]' do
    analyzer_reports([{ coverage_map_id: comms.id, new_state: 'covered', new_probe_count: 3,
                        last_signal: 'Gave two specific examples.' }])

    described_class.new.perform(session.id, 12)

    expect(comms.reload).to have_attributes(state: 'covered', probe_count: 3)
    expect(react.reload.state).to eq('partial')
  end
end
