---
type: Mistake
title: Class reference validation needs module documentation inputs
description: Include module XML when validating links from the core class reference.
tags: [testing, documentation]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# What happened and rule

Running the class-reference checker on `doc/classes` alone reported missing
GDScript and module types. Those definitions live in module documentation;
export-platform types also require platform documentation. Use `doc/classes
modules/*/doc_classes platform/*/doc_classes` together before interpreting
unresolved links as a source regression. Keep sample-parity notices separate
from XML errors and warnings.
