# frozen_string_literal: true

require 'rails_helper'

# Production boots with eager_load = true. Development and test do not, so a
# file whose constant name does not match its path loads fine on a laptop and
# takes the service down on deploy. This is the only check that boots the app
# the way production does.
RSpec.describe 'Application boot' do
  it 'eager-loads every class the way production does [AC-OPS-01]' do
    expect { Zeitwerk::Loader.eager_load_all }.not_to raise_error
  end
end
