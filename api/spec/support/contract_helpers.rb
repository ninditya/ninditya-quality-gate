# frozen_string_literal: true

# Compares a real response against a fixture in /contracts by shape: same keys,
# same JSON types, recursively. Values are free to differ. `null` on either
# side means "nullable" and matches anything.
module ContractHelpers
  CONTRACTS_DIR = [Rails.root.join('../contracts'), Pathname.new('/contracts')].find(&:directory?)

  def contract(name)
    JSON.parse(CONTRACTS_DIR.join("#{name}.json").read)
  end

  # Returns a list of human-readable differences; empty means the shapes match.
  def shape_diff(expected, actual, path = '$')
    return [] if expected.nil? || actual.nil?

    case expected
    when Hash
      return ["#{path}: expected an object, got #{actual.class}"] unless actual.is_a?(Hash)

      missing = (expected.keys - actual.keys).map { |k| "#{path}.#{k}: missing from the API response" }
      extra   = (actual.keys - expected.keys).map { |k| "#{path}.#{k}: not in the contract" }
      nested  = (expected.keys & actual.keys).flat_map { |k| shape_diff(expected[k], actual[k], "#{path}.#{k}") }
      missing + extra + nested
    when Array
      return ["#{path}: expected an array, got #{actual.class}"] unless actual.is_a?(Array)
      return [] if expected.empty? || actual.empty?

      actual.each_with_index.flat_map { |item, i| shape_diff(expected.first, item, "#{path}[#{i}]") }
    else
      json_type(expected) == json_type(actual) ? [] : ["#{path}: expected #{json_type(expected)}, got #{json_type(actual)}"]
    end
  end

  def json_type(value)
    case value
    when true, false then :boolean
    when Numeric     then :number
    when String      then :string
    else value.class.name.downcase.to_sym
    end
  end
end

RSpec.configure { |config| config.include ContractHelpers, type: :request }
