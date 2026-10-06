# frozen_string_literal: true

# Ties an account to the tenant it acts for. Until now nothing did: the login
# endpoint took the tenant from a request header.
#
# Nullable on purpose. Existing accounts have no organization recorded and
# cannot be guessed; they must be assigned before they can sign in again.
# No foreign key: organizations is owned by the core platform's schema.
class AddOrganizationToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :organization_id, :bigint
    add_index  :users, :organization_id
  end
end
