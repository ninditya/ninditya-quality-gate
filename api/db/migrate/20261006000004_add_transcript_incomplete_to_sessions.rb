# frozen_string_literal: true

# A durable "a turn of this interview was not stored".
#
# Transcript turns are written from background threads while audio keeps
# flowing. A write that failed was logged and forgotten, and the portfolio was
# then generated from whatever had been stored. The log line is not something
# an assessor ever sees; this column is what the result pages read.
class AddTranscriptIncompleteToSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :sessions, :transcript_incomplete, :boolean, null: false, default: false
  end
end
