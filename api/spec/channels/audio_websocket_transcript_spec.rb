# frozen_string_literal: true

require 'rails_helper'

# Every rating is generated from the transcript. A turn that fails to store
# used to be logged and forgotten; nobody reading the result could know.
RSpec.describe AudioWebSocketMiddleware do
  subject(:middleware) { described_class.new(->(_env) { [404, {}, []] }) }

  let(:assessment) { create(:assessment, :with_skills) }
  let(:session)    { create(:session, :active, assessment: assessment) }

  def save(number, speaker, text)
    middleware.send(:save_transcript_turn, session, number, speaker, text)
  end

  def stored
    session.transcript_turns.ordered.pluck(:turn_number, :speaker, :text)
  end

  it 'retries a write that failed once, and the turn is stored [AC-TR-01]' do
    calls = 0
    allow(middleware).to receive(:store_turn).and_wrap_original do |original, *args|
      (calls += 1) == 1 ? raise(ActiveRecord::ConnectionTimeoutError, 'pool exhausted') : original.call(*args)
    end

    save(1, 'candidate', 'We split the monolith by team boundary.')

    expect(stored).to eq([[1, 'candidate', 'We split the monolith by team boundary.']])
    expect(session.reload).to be_transcript_complete
  end

  it 'marks the session when a turn cannot be stored at all [AC-TR-01]' do
    allow(middleware).to receive(:store_turn).and_raise(ActiveRecord::StatementInvalid, 'connection lost')

    save(1, 'candidate', 'We split the monolith by team boundary.')

    expect(stored).to be_empty
    expect(session.reload.transcript_incomplete).to be(true)
    expect(session).not_to be_transcript_complete
  end

  it 'treats a hole in the turn numbering as a missing turn, flag or no flag [AC-TR-01]' do
    save(1, 'ai', 'Tell me about a migration you led.')
    save(2, 'candidate', 'We split the monolith by team boundary.')
    save(4, 'candidate', 'We rolled it back twice before it held.')

    expect(session.reload.transcript_incomplete).to be(false)
    expect(session).not_to be_transcript_complete
  end

  it 'keeps both turns when two connections use the same number for different words [AC-TR-02]' do
    save(1, 'candidate', 'We split the monolith by team boundary.')
    save(1, 'ai', 'How did you decide where to cut?')

    expect(stored).to eq([[1, 'candidate', 'We split the monolith by team boundary.'],
                          [2, 'ai', 'How did you decide where to cut?']])
    expect(session.reload).to be_transcript_complete
  end

  it 'skips an exact replay of a turn that is already stored [AC-TR-02]' do
    2.times { save(1, 'candidate', 'We split the monolith by team boundary.') }

    expect(stored.size).to eq(1)
  end
end
