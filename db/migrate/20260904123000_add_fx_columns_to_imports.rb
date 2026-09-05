class AddFxColumnsToImports < ActiveRecord::Migration[7.2]
  def change
    add_column :imports, :exchange_rate_col_label, :string
    add_column :imports, :exchange_rate_from_col_label, :string
    add_column :imports, :exchange_rate_to_col_label, :string
    add_column :import_rows, :exchange_rate, :string
    add_column :import_rows, :exchange_rate_from, :string
    add_column :import_rows, :exchange_rate_to, :string
  end
end
