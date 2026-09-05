class AddSourceToExchangeRates < ActiveRecord::Migration[7.2]
  def change
    add_column :exchange_rates, :source, :string, null: false, default: "provider"
    add_index :exchange_rates, :source
  end
end
