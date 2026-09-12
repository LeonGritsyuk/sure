class ExchangeRate < ApplicationRecord
  include Provided

  validates :from_currency, :to_currency, :date, :rate, presence: true
  validates :date, uniqueness: { scope: %i[from_currency to_currency] }
  SOURCES = %w[provider manual imported].freeze
  validates :source, inclusion: { in: SOURCES }
  validates :rate, numericality: { greater_than: 0 }
  scope :manual_or_imported, -> { where(source: %w[manual imported]) }

  belongs_to :overridden_by, class_name: "User", optional: true

  # Entries whose entryable (Transaction/Trade) already carries its own explicit
  # exchange_rate (e.g. from a CSV import's fx_rate column) don't need a global
  # ExchangeRate row — the custom rate takes priority wherever the entry is
  # converted, so they must not be counted as "missing".
  HAS_CUSTOM_RATE_SQL = <<~SQL.squish
    (
      (entries.entryable_type = 'Transaction' AND EXISTS (
        SELECT 1 FROM transactions
        WHERE transactions.id = entries.entryable_id
          AND transactions.extra ->> 'exchange_rate' IS NOT NULL
      ))
      OR
      (entries.entryable_type = 'Trade' AND EXISTS (
        SELECT 1 FROM trades
        WHERE trades.id = entries.entryable_id
          AND trades.extra ->> 'exchange_rate' IS NOT NULL
      ))
    )
  SQL

  def self.missing_for_family(family)
    required = Entry
      .joins(:account)
      .where(accounts: { family_id: family.id })
      .where.not(currency: family.currency)
      .where.not(HAS_CUSTOM_RATE_SQL)
      .distinct
      .pluck(:date, :currency)

    existing = where(from_currency: required.map(&:last), to_currency: family.currency, date: required.map(&:first))
      .pluck(:date, :from_currency)
      .to_set

    required.filter_map do |date, from_currency|
      next if existing.include?([ date, from_currency ])

      { date: date, from_currency: from_currency, to_currency: family.currency }
    end.sort_by { |missing| [ missing[:date], missing[:from_currency] ] }
  end

  validate :currencies_are_valid
  validate :currencies_must_differ

  private
    def currencies_are_valid
      [ :from_currency, :to_currency ].each do |attribute|
        Money::Currency.new(public_send(attribute))
      rescue Money::Currency::UnknownCurrencyError, ArgumentError
        errors.add(attribute, :invalid)
      end
    end

    def currencies_must_differ
      return if from_currency.blank? || to_currency.blank?
      return unless from_currency.casecmp?(to_currency)

      errors.add(:to_currency, :must_differ, message: "must differ")
    end
end
