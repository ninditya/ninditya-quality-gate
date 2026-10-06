# frozen_string_literal: true

module Sessions
  # Decides why an interview that ended by itself ended.
  #
  # The answer comes from what is stored, never from the caller. The endpoint
  # that reports "the closing audio has finished" is unauthenticated, and the
  # audio socket's own belief about coverage can be out of date.
  module EndReason
    # The interviewer is told to wrap up this long before the limit
    # (AudioWebSocketMiddleware#check_time_ceiling).
    WRAP_UP_WINDOW = 60

    module_function

    # `otherwise` is what to record when neither rule holds, i.e. the interview
    # was cut short. The caller knows who cut it.
    def automatic(session, otherwise:)
      return 'all_covered'  if all_configured_covered?(session)
      return 'time_ceiling' if wrapping_up_on_time?(session)

      otherwise
    end

    # PRD-02, Session End: "ALL configured skills = covered". Discovered skills
    # do not count towards it.
    def all_configured_covered?(session)
      states = session.coverage_maps.configured.pluck(:state)
      states.any? && states.all?('covered')
    end

    def wrapping_up_on_time?(session)
      limit = session.assessment.time_limit_min
      return false unless session.started_at && limit

      Time.current >= session.started_at + (limit * 60) - WRAP_UP_WINDOW
    end
  end
end
