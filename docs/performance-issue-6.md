# Issue 6 performance results

## What changed

Initial scans load top-level entries instead of walking every child directory. Expanding a directory loads its children. Refresh discards stale child listings and reloads the selected document. Directory limits keep primary SKILL.md and README.md entries available.

Metadata reads use 4 KiB blocks with a 64 KiB ceiling instead of loading the whole Markdown file. Tests cover UTF-8, delimiters split across reads, and a closing delimiter at the exact byte limit.

Collection JSON encoding, decoding, and file I/O run off the main actor. Saves run in order and publish only successful snapshots. Import deduplication uses a Set of IDs. CollectionView reuses one filtered and sorted result per body evaluation.

## Measured wall time

Baseline source is commit `9530b293576883b1139fe94363db3e87beec6604`. Both revisions used the same `Issue6BenchmarkTests.swift` fixture, release builds, seven repetitions, and median elapsed time. Baseline and final measurements ran separately on this machine, not as interleaved trials.

Environment: Apple M4, arm64, macOS 26.3, Apple Swift 6.3.2. Fixtures live in temporary directories. These are repeated local filesystem measurements, not cold-cache or UI benchmarks.

| Operation | Before | After | Difference |
| --- | ---: | ---: | ---: |
| Initial scan of eight independent nested skill directories | 24.234 ms | 1.364 ms | 94.4% less time, 17.8x faster |
| Metadata scan of one Markdown file with a 2.5 MB body | 20.215 ms | 0.091 ms | 99.5% less time, about 222x faster |
| Read and decode 10,000 JSON records | 24.343 ms | 24.894 ms | No demonstrated improvement |

The scan fixture has eight levels. At each level it creates three child directories with four files each, then continues down the first child. This is not a full three-way branching tree.

The large metadata result comes from skipping the body. It does not mean Markdown rendering is 222x faster. Directory work is deferred until expansion, not removed when a user opens every directory.

The JSON measurement covers reading and decoding, despite the benchmark output calling it "full JSON import". It does not time the complete UI import, merge, and save flow. Each fixture generates UUIDs and timestamps, so JSON size varies slightly around 2.218 MB. The 0.551 ms difference is not evidence of a meaningful regression or improvement.

## Work avoided

| Operation | Before | After |
| --- | ---: | ---: |
| Materialized nodes during the nested fixture's initial scan | 968 | 32 |
| Metadata input for the large-body fixture | Entire file, over 2.5 MB | At most 65,536 bytes, usually less |
| Deduplicating 10,000 unique incoming IDs into an empty collection | 49,995,000 linear comparisons | 10,000 Set insertion checks |
| Filter/sort passes for a nonempty collection body evaluation | Two property accesses | One shared result |

Node count falls by 96.7% during initial scanning. The ID counts describe the algorithms for this fixture, not measured CPU instructions or a 5,000x timing improvement. Constructing the Set also costs work when the collection already contains entries.

Moving JSON work off the main actor reduces work scheduled on that actor. We have not measured the resulting frame-time or responsiveness change.

## Reproduce

Run the final fixture on this branch:

```sh
swift test -c release --filter Issue6BenchmarkTests
```

To run the same fixture against the baseline without resetting the current checkout:

```sh
baseline="$(mktemp -d /tmp/skillhub-issue6-baseline.XXXXXX)"
git archive 9530b293576883b1139fe94363db3e87beec6604 | tar -x -C "$baseline"
cp Tests/SkillHubTests/Issue6BenchmarkTests.swift "$baseline/Tests/SkillHubTests/"
(cd "$baseline" && swift test -c release --filter Issue6BenchmarkTests)
```

The baseline directory is disposable. Compare release runs on the same machine and keep fixture setup outside the measured operation. Do not use these single-machine timings as CI thresholds.

## Validation and remaining work

Debug and release suites each pass 52 tests. The exact-limit metadata regression failed before the EOF fix and passed afterward. `git diff --check` passes.

Source-preview sizing and window-wide scroll-policy traversal remain unchanged. Issue 6 items 5 and 6 need actual first-display, text-selection, scrolling, and view-traversal measurements before further changes. This report makes no UI frame-time, launch-time, or peak-memory improvement claim.
