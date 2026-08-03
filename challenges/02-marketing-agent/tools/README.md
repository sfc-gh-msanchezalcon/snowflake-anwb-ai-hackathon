# Tools - Marketing Agent

This challenge has **no external API tools** to set up. The only "tool" is the deck
generator, and it's created for you by `../run_all.sql`:

- The campaign **deck defaults to HTML** (generated with `AI_COMPLETE`, no packages).
- An optional **`.pptx`** path uses the `build_deck` stored procedure (`python-pptx`),
  created in `run_all.sql` inside a guarded block. It only works if the Anaconda
  packages are enabled for your account (Snowsight > Admin > Billing & Terms >
  accept Anaconda). If not enabled, `run_all.sql` simply skips it and you keep the
  HTML deck.

Everything the agent needs (products, segments, past campaigns, the `MARKETING_KB`
Cortex Search service) is provisioned by `run_all.sql` or `marketing_agent.ipynb`.
