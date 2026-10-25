---
type: Finding
title: Discard script documentation cache callbacks after editor teardown
description: A stale editor documentation cache can leave a deferred script-cache callback queued after EditorNode is destroyed, causing a headless import shutdown crash.
tags: [editor, gdextension, documentation, lifetime, testing]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
sources:
  - id: editor-help
    resource: ../../editor/doc/editor_help.cpp
    title: Documentation workers and deferred script-cache loading
  - id: editor-node
    resource: ../../editor/editor_node.cpp
    title: EditorNode destruction and command-line mode accessor
  - id: main-cleanup
    resource: ../../main/main.cpp
    title: Main-loop destruction, editor type teardown and message queue cleanup
  - id: extension-unregister
    resource: ../../core/extension/gdextension.cpp
    title: Extension class unregistration and optional documentation removal
---

# Failure and reproduction

The `d37b63e72b` headless import of the path tracer fixture finished loading
the editor layout, then reported `EditorNode::is_cmdline_mode` with a null
singleton and exited with `0xC0000005`. The same message and crash were already
present in an older `3e024c0a0` import. An `e0c27964e8` receipt exited zero but
its raw log still contained this error and a thread-cleanup warning; that
receipt does not establish a clean import.

CPU-only controls used frozen `1000baebda`, `d040fbbe7d` and `d37b63e72b`
editors, the explicit dummy renderer, a non-CUDA physics backend, and isolated
caches. The d37 empty project and the same project with the existing native
GDExtension both passed with cold and matching warm caches. The old editors
with that extension also passed those two cache states.

Seeding each d37 control with the real `1000baebda` editor documentation
cache reproduced the identical null-singleton error and `0xC0000005` in
both projects, including the project containing no GDExtension. Neither
control initialized a Vulkan/D3D12 rendering device or a CUDA context.
The extension is therefore not a necessary trigger, and suppressing its
registration or unregistration would not address this defect.

# Lifetime boundary

When an existing native documentation cache has a different version hash,
`_load_doc_thread` defers a regeneration to the main thread. Documentation
workers also defer `load_script_doc_cache`. `EditorNode` destruction joins
the documentation worker in `cleanup_doc`, then clears the singleton;
the worker can enqueue its follow-up before that join completes. Later
queued work can consequently run after the editor has been destroyed.

The script-cache callback previously tested project presence and then
called `EditorNode::is_cmdline_mode`. A missing editor makes that accessor
report an error and return false, permitting the callback to continue into
editor path/filesystem services whose lifetime has also ended. The
null-singleton message is not evidence that extension class removal directly
called this accessor: its documentation-removal path checks whether doc
data still exists and does not call `is_cmdline_mode`.[^editor-help]

# Minimal change and limits

`load_script_doc_cache` now returns immediately when `EditorNode` does not
exist, before accessing project/editor services. Existing no-project and
command-line early returns remain in place. This applies the consumer's
lifetime boundary to a deferred callback; native extension registration,
unregistration and real import diagnostics remain enabled.

Normal editor use schedules this callback after EditorNode has been
constructed, so it follows the existing cache path. Native documentation
generation used by API dumps and the project manager remains available;
only script-cache loading that requires an EditorNode is guarded. No global
message queue ordering or worker scheduling is changed.

The before-control reproductions are measured. The candidate still needs a
rebuilt editor to run the same old-cache controls, the original fixture's
import, and a normal editor cache-load control before marking the fix
verified. This change does not claim to solve every possible deferred
documentation or threaded-renderer lifetime issue.

[^editor-help]: See the worker callbacks, `load_script_doc_cache`, and `cleanup_doc` in the editor-help source, together with EditorNode teardown and extension class removal.
