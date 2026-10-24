---
type: Mistake
title: Sandbox socket denial looked like an engine regression
description: Verify test infrastructure permissions before interpreting a network fixture crash as a merge defect.
tags: [testing, sandbox, networking]
status: stable
generated: { by: codex, at: 2026-10-24T00:00:00Z }
---

# What happened

The first 4.8 beta 1 native suite ran in a sandbox that prohibited creating
sockets. The inherited TCP test helper failed its `REQUIRE`s, returned an
empty peer, and the caller dereferenced it. The resulting SIGSEGV initially
looked like an engine regression.

# Evidence and rule

The fixture was unchanged from the official baseline. Enabling the supported
network permission and running the exact full command again passed all 1465
cases and 442079 assertions, without a source patch or excluded test.

Check the first failing assertion and environment permission before the
crash stack. Preserve the original failure log, correct the execution
environment, and repeat unchanged. Native unit suites intentionally emit
some error messages in negative tests; use their assertions, final summary
and exit status rather than declaring every `ERROR:` line a failed suite.
