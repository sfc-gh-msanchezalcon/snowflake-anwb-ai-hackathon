# Tools - ReisNogWijzer

**You don't need to run anything here to start.** The zero-setup **mock tools**
(`mock_rdw_lookup`, `mock_weather`, `travel_advisory_tool`, `mock_currency`) are
created for you by `../run_all.sql` (or the notebook). They return canned data and
always work - no network required.

## Optional stretch: real live tools

`real_tools.sql` swaps the mocks for **live** public APIs (RDW open vehicle data +
open-meteo weather) via a Snowflake External Access Integration.

- Needs a role with `CREATE INTEGRATION` (usually `ACCOUNTADMIN`) and outbound egress.
- Run it **after** `run_all.sql`. It creates `real_rdw_lookup` and `real_weather`
  alongside the mocks.
- If your account's network policy blocks egress, skip it - the mocks cover the
  whole challenge.
