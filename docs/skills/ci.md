# CI disk-space preparation

## When to use

Use this guidance when changing a hosted workflow that builds or extracts
large OCI, OSTree, or ISO payloads.

## Pattern

Hosted runners should reclaim disk space before large payload extraction. The
common image build workflow starts with
`ublue-os/remove-unwanted-software@v10` and enables `extra-squeeze: "true"`.
Keep this step immediately after checkout so later package installation and
image assembly benefit from the reclaimed space.

The pinned action reference currently used by the shared runner action is:

```yaml
uses: ublue-os/remove-unwanted-software@695eb75bc387dbcd9685a8e72d23439d8686cba6 # v10
with:
  extra-squeeze: "true"
```

## Verification

Re-derive the workflow behavior from source before changing this guidance:

```bash
grep -n -A8 -B3 'Free disk space' .github/workflows/build.yml
gh api repos/projectbluefin/actions/contents/bootc-build/setup-runner/action.yml \
  --jq .content | base64 -d | grep -n -A5 -B3 'Maximize build space'
```
