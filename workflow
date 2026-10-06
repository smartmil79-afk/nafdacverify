# Copies the NAFDAC Greenbook into Supabase on the 1st of every month (and on demand).
# Needs ingest-greenbook.mjs in the repository root.
name: Sync NAFDAC Greenbook

on:
  schedule:
    - cron: "0 3 1 * *"        # 03:00 UTC on the 1st of each month (GitHub may start it a little late)
  workflow_dispatch:           # "Run workflow" button in the Actions tab
    inputs:
      dry_run:
        description: "Dry run: check the connection and column mapping, write nothing"
        type: boolean
        default: false

concurrency:
  group: greenbook-sync
  cancel-in-progress: false

permissions:
  contents: read

jobs:
  sync:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Run Greenbook sync
        env:
          GB_URL: ${{ secrets.GB_URL }}
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
          GB_DELAY_MS: "600"
          PRUNE: ${{ vars.PRUNE }}          # optional repository variable: set to 1 to delete products removed from the Greenbook
        run: |
          if [ "${{ inputs.dry_run }}" = "true" ]; then
            node ingest-greenbook.mjs --dry
          else
            node ingest-greenbook.mjs
          fi
