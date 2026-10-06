# frozen_string_literal: true

# The edit forms submit the rows that remain on screen. A row the user removed
# is simply absent from the list, and accepts_nested_attributes_for ignores an
# absent row: the skill stayed in the database while the screen showed it gone.
#
# This turns "absent" into an explicit removal, so the stored list always
# equals the submitted one.
module SubmittedList
  private

  # attributes: permitted params that may carry a nested list under `key`
  # stored:     the rows that exist now
  #
  # A request that does not mention the list at all leaves it untouched.
  def replacing_list(attributes, key, stored)
    return attributes unless attributes.key?(key)

    submitted = attributes[key]
    rows      = (submitted.respond_to?(:values) ? submitted.values : Array(submitted)).map(&:to_h)
    kept_ids  = rows.filter_map { |row| row['id'].presence&.to_s }
    removals  = stored.reject { |record| kept_ids.include?(record.id.to_s) }
                      .map { |record| { 'id' => record.id, '_destroy' => true } }

    attributes.to_h.merge(key.to_s => rows + removals)
  end
end
