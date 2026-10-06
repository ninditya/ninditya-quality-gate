# frozen_string_literal: true

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # A focused or skipped example is a hole in the net. CI refuses both, so a
  # check can only leave the suite through a reviewed diff, never an `xit`.
  if ENV['CI']
    config.before(:each, :focus) { raise 'focused examples (fit/fdescribe) are not allowed in CI' }
    config.before(:each, :skip)  { raise 'skipped examples (xit/skip) are not allowed in CI' }
  else
    config.filter_run_when_matching :focus
  end
end
