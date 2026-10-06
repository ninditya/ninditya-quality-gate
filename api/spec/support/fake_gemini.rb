# frozen_string_literal: true

# Stands in for Gemini::HttpClient. The real client returns already-parsed JSON,
# so the fake does too. Records prompts so a spec can assert what was sent.
class FakeGemini
  attr_reader :prompts

  def initialize(response = {}, error: nil)
    @response = response
    @error    = error
    @prompts  = []
  end

  def generate_content(prompt, **_opts)
    @prompts << prompt
    raise @error if @error

    @response.respond_to?(:call) ? @response.call(prompt) : @response
  end
end
