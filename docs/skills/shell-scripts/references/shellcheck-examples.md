# Shellcheck Examples

Part of [shell-scripts](../SKILL.md) — shellcheck directive syntax, SC code notes, and quoting fix examples.

<!-- TODO(context7): verify all shellcheck SC codes and directive syntax against shellcheck docs -->

## Disable comment — no inline notes (SC1072/SC1073)

```bash
# WRONG:
# shellcheck disable=SC2086 -- SET_PIN_ARG intentionally unquoted
# CORRECT — directive alone on its own line:
# shellcheck disable=SC2086
sudo cmd ${OPTIONAL_ARG} "${REQUIRED_ARG}"
```

## Profile.d scripts without shebangs (SC2148)

```bash
# shellcheck shell=bash
alias neofetch='ublue-fastfetch'
```

## Suppress SC1091 (source-following info) for the find step

```yaml
- name: Run shellcheck — .sh scripts
  run: find system_files -name '*.sh' -print0 | xargs -0 shellcheck -e SC1091
```

## Both quoting fixes required for hook runners

When fixing `bash $script` (SC2086), also quote the directory in the for loop:
```bash
# WRONG — word-splits on directory path AND script variable:
for script in $HOOKS_DIR/* ; do
    bash $script
done

# CORRECT — both must be quoted:
for script in "${HOOKS_DIR}"/* ; do
    bash "$script"
done
```
A space in `HOOKS_DIR` will silently fail to find hooks if only `$script` is fixed.
