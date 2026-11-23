---
type: Mistake
title: Empty Git configuration values lost while restoring test environments
description: Separate a malformed injected test environment from the product being validated.
tags: [testing, windows, git, environment]
status: stable
generated: { by: codex, at: 2026-11-24T00:00:00Z }
---

# Observation

A delivery CPU suite failed while initializing temporary Git fixtures. Their
helper suppressed stderr, initially hiding `missing config value
GIT_CONFIG_VALUE_0`. The parent had command-line Git configuration with an empty
value. Restoring `os.environ` during a Windows test dropped the empty value but
retained its key and count; a later `git init` rejected that malformed environment.
No engine or game implementation ran at this failure point.

# Rule

Preserve the original failed run. Capture the actual subprocess error before
changing product code or weakening assertions. For local fixture repositories,
use a test subprocess without injected `GIT_CONFIG_COUNT` / `KEY_n` / `VALUE_n`
variables, and record that adjustment. Do not change user/global Git settings or
the test's expected behavior. Bind subsequent results to commands, exit codes,
input hashes and their exact environment; earlier output alone cannot certify
a later delivery tree.
