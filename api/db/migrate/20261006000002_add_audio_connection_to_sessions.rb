# frozen_string_literal: true

# Which audio connection currently belongs to the candidate.
#
# Every browser connection, including a reconnect after a network blip, gets
# its own in-memory state on the server. The grace timer of a dropped
# connection therefore had no way to learn that the candidate was already back
# on another one, and ended the interview underneath them. The session row is
# the only thing all connections (and all server processes) share, so the
# newest connection records itself here.
class AddAudioConnectionToSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :sessions, :audio_connection_id, :string, limit: 32
  end
end
