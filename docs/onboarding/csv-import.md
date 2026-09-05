# Importing transactions from a CSV file

This guide covers the **manual CSV import** workflow (Settings → Imports → New Import → Transactions), including the optional columns that let you record a transaction in a **foreign currency** with an explicit exchange rate.

> [!IMPORTANT]
> Sure is evolving quickly. If you find something inaccurate while following this guide, please:
>
> - Ask in the [Discord](https://discord.gg/36ZGBsxYEK)
> - Open an [issue](https://github.com/we-promise/sure/issues/new/choose)
> - Or if you know the answer, open a [PR](https://github.com/we-promise/sure/compare)!

## 1. The basic workflow

1. Go to **Settings → Imports** and start a **new Transaction import**.
2. Upload your CSV file (max 10 MB).
3. On the **configuration screen**, map each of your CSV's column headers to the fields Sure understands (date, amount, currency, category, etc.) using the dropdowns.
4. Review the **preview table** — it shows a few parsed rows so you can catch mapping mistakes before committing.
5. Map any unrecognized **accounts, categories, or tags** to existing records (or let Sure create new ones).
6. Click **Import** to commit. Rows are matched against existing transactions to avoid duplicates (see [Duplicate handling](#5-duplicate-handling) below).

A "Download CSV template" link is available with a minimal example (`date, amount, name, currency, category, tags, account, notes`). Note that the template does **not** include the FX columns described below — if you need them, add the columns to your own file manually and map them on the configuration screen the same way as any other column.

## 2. Supported columns

| CSV column (yours can be named anything) | Maps to | Required? |
| --- | --- | --- |
| Date | `date` | Yes |
| Amount | `amount` | Yes |
| Name | `name` | No — defaults to a generic name |
| Currency | `currency` | No — defaults to the account's currency (or family currency if no account is set) |
| Exchange rate | `exchange_rate` | No — see [FX columns](#3-fx-columns-exchange-rate-exchange-rate-from-exchange-rate-to) |
| FX from / FX to | `exchange_rate_from` / `exchange_rate_to` | No — see below |
| Category | `category` | No |
| Tags | `tags` | No — pipe or comma separated, e.g. `groceries\|essentials` |
| Account | `account` | Required only if you didn't pick a single target account for the whole import |
| Notes | `notes` | No |

You don't need a column for every field — leave a dropdown on **"(leave empty)"** for anything your file doesn't have.

## 3. FX columns: `exchange_rate`, `exchange_rate_from`, `exchange_rate_to`

These three optional columns let you tell Sure exactly what rate to use when a transaction's currency differs from the account's currency, instead of relying on Sure's automatic exchange-rate lookup (which depends on a configured provider and historical rate availability).

| Column | Meaning |
| --- | --- |
| `exchange_rate` | The numeric rate used to convert the row's `amount` (in the row's `currency`) into the account's currency. Must be a positive number. |
| `exchange_rate_from` | The source currency of the rate (informational — validated as a real ISO currency code, e.g. `KZT`). |
| `exchange_rate_to` | The target currency of the rate (informational — validated as a real ISO currency code, e.g. `CZK`). |

**How the rate is applied:** `exchange_rate` is stored directly on the imported transaction and used whenever Sure needs to display or total that transaction in your account/family currency — it takes priority over any automatically fetched exchange rate for that specific transaction.

**About `exchange_rate_from` / `exchange_rate_to`:** these two columns are validated (they must be real currency codes) and stored for your own reference, but Sure does **not** currently cross-check them against the row's `currency` column or the account's actual currency. In practice, only `exchange_rate` affects the imported amount — `exchange_rate_from`/`exchange_rate_to` are optional documentation of what the rate represents. You can safely map only `exchange_rate` and skip the other two if you don't need the extra audit trail.

### Example

Say your account is in **CZK**, but your bank's export gives you a transaction in **KZT** (Kazakhstani tenge) along with the exact rate the bank used:

```csv
date,amount,currency,fx_from,fx_to,fx_rate
2026-01-01,10000,KZT,KZT,CZK,0.00523
```

On the configuration screen:
- Map **Amount** → `amount`, **Currency** → `currency`
- Map **Exchange rate** → `fx_rate`
- Optionally map **FX source currency** → `fx_from` and **FX target currency** → `fx_to`

The resulting transaction is recorded with `currency: "KZT"` and an explicit `exchange_rate` of `0.00523`, so its converted value (≈ 52.30 CZK) is exact — no dependency on Sure's exchange-rate provider finding a KZT↔CZK rate for that date.

> [!Note]
> If you **don't** provide an `exchange_rate`, Sure falls back to its normal automatic exchange-rate lookup for that date. If no rate can be found there either, the amount is **excluded** from currency-converted totals (dashboards, reports) rather than being silently assumed to be 1:1 with your family currency.

## 4. Updating an existing transaction's rate

If a re-import matches an existing transaction (see below), and your CSV row has an `exchange_rate` value, that rate **overwrites** the existing transaction's stored rate. This is useful for correcting a rate after the fact — just re-import the same rows with the corrected `exchange_rate` column.

## 5. Duplicate handling

Rows are matched against existing entries in the target account by **date + signed amount + currency + name**. When a match is found:
- The existing transaction's category/tags/notes/exchange rate are updated (only for fields you provided).
- The entry is marked as imported/locked so a future provider sync won't silently overwrite your manual edits.

When no match is found, a new transaction is created.

## 6. Signage conventions

Whether a positive amount in your CSV means money coming in or going out depends on your bank's export format. Use the **Amount type** setting on the configuration screen:
- **Signed amount** — a single amount column where you tell Sure whether positive numbers are inflows or outflows.
- **Custom column** — a separate column (e.g. "Debit"/"Credit" or "Type") identifies the direction per row.
