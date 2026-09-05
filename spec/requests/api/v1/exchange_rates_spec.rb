require 'swagger_helper'

RSpec.describe 'API V1 Exchange Rates', type: :request do
  let(:family) do
    Family.create!(name: 'Exchange Rate API Family', currency: 'USD', locale: 'en', date_format: '%m-%d-%Y')
  end

  let(:user) do
    family.users.create!(email: 'exchange-rates-api@example.com', password: 'password123', password_confirmation: 'password123')
  end

  let(:api_key) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(user: user, name: 'Exchange Rate API Key', key: key, scopes: %w[read_write], source: 'web')
  end

  let(:'X-Api-Key') { api_key.plain_key }
  let(:exchange_rate) do
    ExchangeRate.create!(from_currency: 'KZT', to_currency: 'CZK', date: Date.new(2001, 1, 1), rate: 0.00523, source: 'manual')
  end

  let(:id) { exchange_rate.id }
  let(:body) do
    { from_currency: 'KZT', to_currency: 'CZK', date: '2001-01-02', rate: 0.00523, source: 'manual' }
  end

  path '/api/v1/exchange_rates' do
    get 'List exchange rates' do
      tags 'Exchange Rates'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      parameter name: :from, in: :query, type: :string, required: false
      parameter name: :to, in: :query, type: :string, required: false
      parameter name: :date, in: :query, type: :string, required: false
      parameter name: :source, in: :query, type: :string, required: false

      response '200', 'exchange rates listed' do
        schema type: :array, items: {
          type: :object,
          required: %w[id from to date rate source updated_at],
          properties: {
            id: { type: :string, format: :uuid },
            from: { type: :string },
            to: { type: :string },
            date: { type: :string, format: :date },
            rate: { type: :number, format: :float },
            source: { type: :string, enum: %w[provider manual imported] },
            updated_at: { type: :string, format: :'date-time' }
          }
        }
        let(:from) { 'KZT' }
        let(:to) { 'CZK' }
        let(:date) { '2001-01-01' }
        let(:source) { 'manual' }
        let!(:exchange_rate) { super() }
        run_test!
      end
    end

    post 'Create or override an exchange rate' do
      tags 'Exchange Rates'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: %w[from_currency to_currency date rate],
        properties: {
          from_currency: { type: :string },
          to_currency: { type: :string },
          date: { type: :string, format: :date },
          rate: { type: :number, format: :float, minimum: 0 },
          source: { type: :string, enum: %w[manual imported] }
        }
      }

      response '200', 'exchange rate created or overridden' do
        schema type: :object
        run_test!
      end
    end
  end

  path '/api/v1/exchange_rates/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Retrieve an exchange rate' do
      tags 'Exchange Rates'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      response '200', 'exchange rate retrieved' do
        schema type: :object
        run_test!
      end
    end

    patch 'Update an exchange rate' do
      tags 'Exchange Rates'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: { type: :object }
      response '200', 'exchange rate updated' do
        schema type: :object
        run_test!
      end
    end

    delete 'Delete an exchange rate' do
      tags 'Exchange Rates'
      security [ { apiKeyAuth: [] } ]
      response '204', 'exchange rate deleted' do
        run_test!
      end
    end
  end
end
