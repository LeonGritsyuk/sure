class AddExchangeRateOverrideAudit < ActiveRecord::Migration[7.2]
  def change
    add_column :exchange_rates, :previous_rate, :decimal
    add_column :exchange_rates, :overridden_by_id, :uuid
    add_column :exchange_rates, :overridden_at, :datetime
    add_index :exchange_rates, :overridden_by_id
    add_foreign_key :exchange_rates, :users, column: :overridden_by_id
  end
end
