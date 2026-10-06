# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'sidekiq/testing'

Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# Background jobs are recorded, never executed implicitly. A spec that cares
# about a job's effect runs it explicitly, so nothing reaches the network.
Sidekiq::Testing.fake!

# Throttling is covered by its own spec; everywhere else it only adds flakiness.
Rack::Attack.enabled = false

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include AuthHelpers
  config.include JsonHelpers, type: :request

  config.before do
    Sidekiq::Worker.clear_all
    # Tenant context lives in RequestStore. Leaking it between examples would
    # make a tenant-isolation spec pass for the wrong reason.
    RequestStore.clear!
  end
end
