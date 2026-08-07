---
name: queue-feed
version: "1.0"
last_updated: 2026-08-03
id: queue-feed
one_line_purpose: Read and validate the Project Bluefin static pull-request queue feed.
entry_point: docs/skills/queue-feed.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [queue, pull-requests, json, redirects]
description: >-
  Reads the Project Bluefin static pull-request queue as validated JSON. Use
  when inspecting queue.projectbluefin.io, filtering its queue items, or
  verifying its root redirect targets queue.json.
metadata:
  type: procedure
  context7-sources: [/curl/curl]
---

# Queue Feed

## When to Use

Use this for a read-only snapshot of the Project Bluefin pull-request queue.
Use Hive to assign contributor work; the feed does not authorize assignment,
ordering, labels, or pull-request mutations.

## When Not to Use

Do not use this feed to select Hive work, mutate pull requests, or replace
GitHub as the source of pull-request review and merge state.

## Core Process

1. Fetch the explicit JSON endpoint, never the hostname root:

   ```bash
   curl --fail --silent --show-error --location --max-time 20 \
     https://queue.projectbluefin.io/queue.json |
     jq -e '(.generated_at | type == "string") and (.items | type == "array")'
   ```

2. Filter only the fields needed for the current read:

   ```bash
   curl --fail --silent --show-error --location --max-time 20 \
     https://queue.projectbluefin.io/queue.json |
     jq -r '.items[] | [.id, .repository, .number, .title, .url] | @tsv'
   ```

3. Verify the root hostname redirects to the JSON endpoint:

   ```bash
   expected='https://queue.projectbluefin.io/queue.json'
   actual=$(curl --silent --show-error --head --max-time 20 \
     --write-out '%{redirect_url}' --output /dev/null \
     https://queue.projectbluefin.io/)
   test "$actual" = "$expected"
   ```

If the redirect check fails, correct the hostname's redirect rule to target
exactly `https://queue.projectbluefin.io/queue.json`. Keep machine consumers on
the explicit `.json` URL even after the redirect is corrected.

## Common Rationalizations

- "The root URL is shorter." It can resolve to HTML; machine consumers use the
  explicit `.json` endpoint.
- "The queue order grants selection authority." It is a read-only snapshot;
  Hive remains the task selector.

## Red Flags

- Treating an HTML response as queue data.
- Reusing a cached snapshot for a new operational decision.
- Inferring queue order or eligibility as authorization to select work.
- Pointing the root redirect at the HTML dashboard rather than `queue.json`.

## Verification

```bash
curl --fail --silent --show-error --location --max-time 20 \
  https://queue.projectbluefin.io/queue.json |
jq -e '(.generated_at | type == "string") and (.items | type == "array")'
```
