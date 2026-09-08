# Memory investigation

## Idle baseline

The reported screenshot shows 222 MB for SkillHub, but does not identify the tool's memory metric. That process had already exited, so its allocations could not be inspected.

Local measurements on Apple M4, macOS 26.3, arm64 release build, about 12 seconds after launching the executable with the default Agent skills page and the local Excalidraw skill selected:

| Measurement | Before image fix | After image fix |
| --- | ---: | ---: |
| `ps` RSS (KiB) | 204,320 | 205,152 |
| `vmmap` physical footprint | 118.0 MiB | 118.8 MiB |
| Live malloc allocations | 66.3 MiB | — |
| AttributeGraph zone live allocations | 9,457 KiB | 9,460 KiB |

These are single-run observations, not a benchmark demonstrating an idle-memory reduction. RSS and physical footprint account for memory differently; neither should be compared blindly with an unidentified monitor's number. Large virtual address reservations are not physical RAM usage.

The default document contains 613 lines / 23,798 bytes. MarkdownUI renders its block sequence eagerly in a VStack. SwiftUI view/layout state is therefore a plausible substantial contributor, even though the input text is small. The large AttributeGraph allocation count supports that interpretation, but does not attribute every allocation or establish a leak. A longer browsing trace with Instruments is still needed to diagnose retention over time.

## Fixed: full-resolution image decoding

Previously, local Markdown images used `NSImage(contentsOf:)`, checking only that the compressed file was at most 10 MB. Compressed size does not bound decoded bitmap size.

`LocalImageLoader` now uses ImageIO thumbnail decoding:

- Block images: at most 1,600 pixels on the longest edge.
- Inline images: at most 256 pixels on the longest edge.
- Preserves aspect ratio and applies orientation transforms.
- Disables source image caching, retains only the thumbnail, and reads at most 10 MB plus one byte to detect oversized input.
- Keeps remote images disabled. Unsupported or invalid images show the existing placeholder; there is no unbounded full-resolution fallback.
- Clears a block image's previous state when its URL changes.

The regression fixture is a 4,096 × 4,096 PNG compressed to 304,307 bytes. Its full 8-bit RGBA bitmap would occupy 67,108,864 bytes (64 MiB). The actual thumbnail is 10,240,000 bytes (9.77 MiB), about 85% smaller. Inline output is at most 256 × 256. This measures the retained bitmap, not peak decoder memory or total process footprint. ImageIO may allocate temporary working buffers, and multiple visible images still accumulate.

This fix prevents avoidable image-related growth; it does **not** resolve or explain the entire reported 222 MB. It does not reduce the image-free default page's memory usage. The source change also does not replace an already installed app.

## Reproduce

Run from the repository in a logged-in macOS desktop:

```sh
swift test
swift build -c release
.build/release/SkillHub >/tmp/skillhub-memory.log 2>&1 &
pid=$!
sleep 12
ps -p "$pid" -o pid,rss,vsz,etime
vmmap -summary "$pid"
kill "$pid"  # Only the process launched above.
```

For comparisons, use the same document, window size, build configuration, and elapsed time. `swift test --filter ImageMemoryTests` prints the fixture's compressed and decoded sizes. Validation: 55 tests passed; release build passed.
