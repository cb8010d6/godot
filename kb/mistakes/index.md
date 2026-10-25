# Mistakes

* [VUID names without message context](/mistakes/vuid-name-without-message-context.md) - classify actual resources and commands before implementing an adapter

* [Optional native probe in a fresh fixture](/mistakes/optional-native-probe-in-fresh-fixture.md) - load and require the extension before accepting runtime/FG state evidence

* [A legacy D3D12 control must retain loader initialization](/mistakes/d3d12-legacy-control-initialization.md) - skip only factory creation and verify the failure stage

* [Class reference validation needs module inputs](/mistakes/class-docs-module-inputs.md) - include module XML before judging unresolved links

* [NGX updater process accumulation](/mistakes/ngx-updater-process-accumulation.md) - contain test children and measure memory ownership before declaring an engine leak

* [Unpinned physics example](/mistakes/unpinned-physics-example.md) - use a repository-owned physics fixture and preserve first-import failures

* [An editor fixture also needs a solution before managed export](/mistakes/incomplete-managed-export-fixture.md) - check complete export inputs, logs, outputs and actual game execution
* [A managed smoke needs the managed runtime environment](/mistakes/managed-smoke-runtime-environment.md) - supply SDK discovery settings to fresh runtime commands
* [Sandbox socket denial looked like an engine regression](/mistakes/sandbox-sockets-in-native-tests.md) - fix execution permissions before changing or excluding a network test

Mistakes agents made in this project: what went wrong, why, and the rule
that prevents it. Read these before testing or measuring. Add one whenever
something goes wrong: a false claim, a wasted rebuild, a test that
measured the wrong thing, a correction from the user.
What worked is in [successes](/successes/).

* [Reported a bug from runs that hadn't converged](/mistakes/conclusions-from-unconverged-runs.md) - repeat and converge before claiming a difference
* [Metrics that measured noise](/mistakes/metric-measured-noise.md) - measure the noise floor first, then pick thresholds
* [Ran a GI test with auto exposure and real-time timing](/mistakes/uncontrolled-test-conditions.md) - pin everything that adapts or animates over time
* [Assumed shader cost scales with work](/mistakes/assumed-cost-scales-with-work.md) - measure the code compiled out first
* [Tuned for speed before checking flicker](/mistakes/tuned-speed-before-stability.md) - run the whole suite per variant
* [Test script bugs looked like engine bugs](/mistakes/script-bugs-taken-for-engine-bugs.md) - fail fast on script errors, check tests on known answers
* [Credited a fix on 3 runs of a noisy test](/mistakes/three-runs-of-a-noisy-test.md) - know the test's spread on the baseline first
* [Mixed up an encoding convention](/mistakes/encoding-convention-mismatch.md) - check the value range of shared helpers before pairing them
* [Quoting broke generated scripts](/mistakes/generated-code-quoting.md) - put code in files, make edits all-or-nothing
* [A test setting lived in the animation callback](/mistakes/test-setting-in-animation-callback.md) - still tests ran with the wrong sun; check one final image of a new scene
* [Recorded a long run of a scene that couldn't show the problem](/mistakes/long-run-of-an-unfit-scene.md) - check one frame shows the effect before a long run
