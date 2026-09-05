require "test_helper"

class Api::V1::ExchangeRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.api_keys.active.destroy_all
    @api_key = ApiKey.create!(
      user: @user,
      name: "Exchange rates key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "exchange_rates_#{SecureRandom.hex(8)}"
    )
  end

  test "lists exchange rates with filters" do
    rate = ExchangeRate.create!(from_currency: "KZT", to_currency: "CZK", date: Date.current, rate: 0.00523, source: "manual")

    get api_v1_exchange_rates_url, params: { from: "kzt", to: "czk", source: "manual" }, headers: api_headers(@api_key)

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal [ rate.id ], response_data.map { |item| item["id"] }
    assert_equal "manual", response_data.first["source"]
  end

  test "creates and updates an exchange rate idempotently" do
    params = { from_currency: "KZT", to_currency: "CZK", date: Date.current, rate: "0.00518", source: "imported" }

    assert_difference "ExchangeRate.count", 1 do
      post api_v1_exchange_rates_url, params: params, headers: api_headers(@api_key)
    end
    assert_response :success
    # Random UUID primary keys mean .last isn't reliably the just-created row
    # once fixtures are in the table, so look it up by its unique key instead.
    rate = ExchangeRate.find_by!(from_currency: "KZT", to_currency: "CZK", date: Date.current)
    assert_equal "imported", rate.source

    assert_no_difference "ExchangeRate.count" do
      post api_v1_exchange_rates_url, params: params.merge(rate: "0.00523", source: "manual"), headers: api_headers(@api_key)
    end
    assert_response :success
    assert_equal 0.00523, rate.reload.rate.to_f
    assert_equal "manual", rate.source
  end

  test "requires write scope to create exchange rates" do
    read_key = ApiKey.create!(
      user: @user,
      name: "Read-only exchange rates key",
      scopes: [ "read" ],
      source: "web",
      display_key: "exchange_rates_read_#{SecureRandom.hex(8)}"
    )

    post api_v1_exchange_rates_url,
      params: { from_currency: "KZT", to_currency: "CZK", date: Date.current, rate: "0.00523" },
      headers: api_headers(read_key)

    assert_response :forbidden
  end
end
