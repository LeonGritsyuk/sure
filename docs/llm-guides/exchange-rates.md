# Exchange rates

## Pair direction

An exchange-rate row stores the value of one unit of `from_currency` in `to_currency`.
For example, `KZT -> CZK` with a rate of `0.00523` means `1 KZT = 0.00523 CZK`.
The inverse pair is stored separately when provider synchronization creates it.

## Sources and precedence

`ExchangeRate#source` identifies the effective row as one of:

- `provider`: fetched or synchronized from the configured provider
- `manual`: entered or overridden by a user
- `imported`: explicitly supplied by an API or import workflow

There is one effective row per `(from_currency, to_currency, date)`. Exact-date rows win.
When the resolver uses its existing short historical lookback, manual/imported rows are
preferred over provider rows. Provider synchronization never replaces an existing
manual or imported row.

## Missing rates

A missing foreign-currency rate is unresolved. It is never interpreted as `1.0`; `1.0`
is reserved for same-currency conversion. `ExchangeRate.missing_for_family` identifies
foreign-currency entries whose exact pair/date row is absent. The Settings exchange-rate
page and `/api/v1/exchange_rates/missing` expose those gaps for review.

Reports and aggregate queries omit unresolved foreign-currency amounts rather than
presenting a false 1:1 conversion. The resulting totals should be treated as incomplete
until the missing rates are entered.

## Manual management

Users with member or admin access can add, edit, and delete rates at Settings > Exchange
rates. Saving a rate for an existing pair/date updates that effective row and marks it
`manual`, overriding a provider value. Provider synchronization leaves that override in
place. The first manual override preserves the previous provider value, actor, and
timestamp in audit fields on the effective row.

## CSV imports

Transaction imports optionally map `fx_rate`, `fx_from`, and `fx_to` columns. The rate is
stored on the imported transaction as a transaction-specific exchange rate. It does not
become a global daily rate, because negotiated card, cash, and transfer rates may differ
from the official daily rate and must not affect unrelated transactions.

Legacy CSV files remain valid when these columns are absent. FX rates must be positive,
and supplied FX currencies must be valid currency codes.

## API

The API uses the existing `X-Api-Key` or OAuth authentication and read/read-write scopes:

- `GET /api/v1/exchange_rates`
- `GET /api/v1/exchange_rates/:id`
- `GET /api/v1/exchange_rates/missing`
- `POST /api/v1/exchange_rates`
- `PATCH /api/v1/exchange_rates/:id`
- `DELETE /api/v1/exchange_rates/:id`

Create is idempotent for a pair/date. API-created rows use `imported` by default; callers
may explicitly use `manual` or `imported` as the source.
