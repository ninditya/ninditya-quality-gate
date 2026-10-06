# frozen_string_literal: true

require 'rails_helper'

# A candidate whose connection drops for a moment reconnects on a new socket.
# The socket that dropped must not end the interview the candidate is still in.
RSpec.describe AudioWebSocketMiddleware do
  subject(:middleware) { described_class.new(->(_env) { [404, {}, []] }) }

  let(:assessment) { create(:assessment, :with_skills, system_prompt: 'You are an assessor.') }
  let(:session)    { create(:session, :active, assessment: assessment) }

  let(:timers) { [] }

  # A browser socket as the middleware sees it.
  def fake_socket
    instance_double(Faye::WebSocket, send: true, close: true)
  end

  def fake_gemini
    instance_double(Gemini::LiveClient, connect: true, close: true, supersede!: true, connected: true,
                                        accepting_audio?: true, inject_context: true, trigger_opening: true,
                                        silence_pumping?: false, inactivity_close: false)
  end

  def env_for(session)
    Rack::MockRequest.env_for("/ws/sessions/#{session.id}/audio?token=#{session.invite_token}")
  end

  def open_connection
    state  = described_class::ConnectionState.new
    socket = fake_socket
    middleware.send(:handle_browser_open, env_for(session), session.id.to_s, socket, state)
    [socket, state]
  end

  def drop(socket, state)
    middleware.send(:handle_browser_close, Struct.new(:code).new(1006), socket, state, session.id.to_s)
  end

  before do
    allow(Gemini::LiveClient).to receive(:new) { fake_gemini }
    # Capture timers instead of waiting two minutes; run their bodies inline.
    allow(EM::Timer).to receive(:new) do |_delay, &blk|
      timers << blk
      instance_double(EM::Timer, cancel: true)
    end
    allow(Thread).to receive(:new) { |&blk| blk.call }
    allow(EM).to receive(:schedule) { |&blk| blk&.call }
  end

  it 'does not end the interview when the candidate has already reconnected [AC-SES-03]' do
    first_socket, first_state = open_connection

    # Network blip: the first socket closes, the browser reconnects.
    drop(first_socket, first_state)
    open_connection

    # Two minutes later the grace timer of the dropped socket fires.
    timers.each(&:call)

    expect(session.reload.status).to eq('active')
    expect(PortfolioGeneratorWorker.jobs).to be_empty
  end

  it 'ends the interview when the candidate drops again and stays away [AC-SES-03]' do
    first_socket, first_state = open_connection
    drop(first_socket, first_state)
    second_socket, second_state = open_connection
    drop(second_socket, second_state)

    timers.each(&:call)

    expect(session.reload).to have_attributes(status: 'ended', end_reason: 'error')
    expect(PortfolioGeneratorWorker.jobs.size).to eq(1)
  end

  it 'still ends an interview the candidate really abandoned' do
    socket, state = open_connection
    drop(socket, state)

    timers.each(&:call)

    expect(session.reload).to have_attributes(status: 'ended', end_reason: 'error')
  end
end
