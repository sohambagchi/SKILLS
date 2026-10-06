---
name: asm-analysis
description: >
  Standardizes a cross-variant workspace that puts N programs side by side in two
  aligned rows — authored source on top, generated code below — with a portable
  bundle format, a git-tracked annotation store, and workflows for extracting the
  mapping, chunking the corpus for annotation, and keeping both current as the
  code changes. Use when building or extending a source-to-assembly comparison
  viewer, extracting debug-info mappings, annotating generated code, or comparing
  what different compilers or code shapes produce. Triggers: /asm-analysis,
  "compare the assembly", "what does this compile to", "DWARF mapping",
  "source to assembly", "annotate the disassembly", "codegen comparison".
---

# asm-analysis

Builds a **review instrument**: a viewer fused with a curated, durable correspondence
database. The question is not "what does this compile to" — a disassembler answers
that. It is: *across N implementations of the same behaviour, which authored
constructs correspond to each other, what did each one generate, and where does the
correspondence break down?* A human answers that over weeks, so every judgement must
survive rebuilds.

**The bundle format in §4 is the contract.** A project's job is to emit a conforming
bundle; the viewer is a consumer of it. Everything project-specific — languages,
compilers, tag vocabularies, comparison axes — arrives as *values in the bundle*,
never as branches in the viewer. If a viewer ever needs to test a variant by name,
the bundle is underspecified.

The extraction in §6 is a process, not a script: every toolchain reports provenance
differently, and a copied script is wrong in a new project in ways that are hard to
see. The viewer, the validator and the format are generic and are worth sharing;
`asmviz` in this directory is a working reference for all three.

## 1. Vocabulary

Use these words consistently; the format and the UI are built on them.

| Term | Meaning |
|---|---|
| **variant** | One program in the cohort. Owns one column of each row. |
| **cohort** | The full set of variants one bundle carries. |
| **unit** | The navigable chapter of work the analyst selects. Logical, not physical. |
| **container** | The complete addressable body the low view displays. Physical: may hold several units, or a fraction of one. |
| **high row** | One row of the authored representation (a source line). |
| **low row** | One row of the generated representation (an instruction). |
| **provenance frame** | One entry of the attribution stack for a low row. Innermost first; each next frame is the call site of the previous. |
| **mapping** | low row → set of high-row keys. Derived from provenance; overridable by hand. |
| **equivalence group** | A set of high-row keys declared by the analyst to mean the same thing. The only cross-variant correspondence the system treats as truth. |
| **overlay** | Measured per-low-row data attached to the static decode. Optional. |
| **tag / note** | A shared classification label, and free text, on one row. |
| **token family** | A class of operand tokens coloured as one entity. |

## 2. Substitution worksheet

Fill this in before writing anything. The ★ answers are expensive to change later.

| Slot | Question |
|---|---|
| ★ variant | What is one column? |
| ★ unit | What does the analyst navigate? |
| ★ container | What complete body does the low panel show? |
| ★ low-row identity | What names a low row stably? |
| ★ chapter | How is a container classified so the UI can pick a default? |
| high / low row | What is one authored row, one generated row? |
| provenance | What does the toolchain say about a low row's origin, and is it a stack? |
| container enumeration | How do you find complete container ranges? |
| decode | What turns a container into ordered low rows? |
| overlay | Is there measured per-row data? How is its scope stated? |
| token families | Which operand tokens are one entity? |
| shape | What do you normalize away when comparing? |
| unit membership | How do you know which unit a low row belongs to? |

A slot with no answer is informative, not a blocker:

- **No provenance** (no debug info, no source map): the automatic mapping layer
  disappears and *all* correspondence is curated. Everything else works; budget for
  the curation.
- **No overlay**: drop the gutter intensity; declare `relevance: "cited"` (§4) so the
  high panel still has a two-tier row grammar.
- **No containers** (the low representation is not addressable in bodies): use the
  unit as the container. You lose "complete body with dimmed context", nothing else.

This pattern is not specific to machine code. It applies unchanged to
source↔bytecode (container = method, provenance = line-number table),
source↔IR (provenance *is* an inline stack; low-row identity can be
`(function, index)`, which makes re-anchoring far easier), schema↔query-plan
(variant = one index configuration, low row = one plan node), and HDL↔netlist.

## 3. Identity

A key is an API. Getting it wrong is a data migration, not a refactor. Five rules:

1. **Namespace and version every key space.** When identity semantics change, add a
   new version and keep *reading* the old one; never reinterpret existing rows.
2. **A key names what it is about, not where it was seen.** Never a panel index, a
   scroll position, or a row ordinal.
3. **Derived rows carry the artifact's identity; authored rows must not.** Authored
   text outlives builds, so an equivalence group keeps meaning across rebuilds. A low
   row's key carries the artifact hash, which is what makes an annotation *provably*
   about one build.
4. **Never let two things collide into one key, and never silently pick a winner.**
   Surface the conflict (§5).
5. **Keys are opaque to the UI.** Parse them in the key constructors and nowhere else.

Fixed arity, `|`-delimited, `-` for an absent component, `%` and `|` percent-encoded,
addresses lowercase `0x…` normalized *in the constructor* so `0xA1B` and `a1b` cannot
become two rows:

```
hi|1|<variant>|<unit>|<file>|<line>
lo|1|<kind>|<variant>|<artifact-sha256>|<address>
ct|1|<variant>|<artifact-sha256>|<start>|<stop>
```

`ct|` names a container for UI state only and is never an annotation subject; it is
range-based because names alias — several symbols can share one exact range, and
exact-range aliasing is the only overlap to accept.

**Cross-variant auto-linking is declared, not assumed.** The bundle declares
`correspondence.autoLink`: the subset of high-key components that must be equal for
two high rows to link automatically. When variants are built from one shared source
tree, `["file","line"]` makes every shared helper correspond at zero curation cost.
When variants have separate sources, `["variant","unit","file","line"]` links nothing
automatically and all correspondence is authored. One key format, both behaviours —
do not hardcode either.

Unit-scoping has a real cost: a line reviewed under two units is two memberships. Pay
it. The alternative makes "this line as the caller" and "this line as the inlined
callee body" indistinguishable, which is exactly the distinction inlining creates.

## 4. The bundle — generated, disposable

One JSON document, deterministic (sorted keys, fixed separators), regenerated from
sealed inputs, never hand-edited. Ship `bundle.json`; optionally also emit
`bundle.js` containing `window.ASM_BUNDLE = {…}` so the workspace opens over
`file://`, where `fetch` is blocked.

JSON is the format, and it holds to far more rows than it first appears — provided
strings are interned (below). **Size the decision in rows, not bytes:** interned, a
low row costs roughly 150 bytes, so 100k rows is about 15 MB raw and 1.5 MB gzipped.
Past a few hundred thousand rows, or when the viewer takes over a second to parse,
move to a lazily-queryable container rather than sharding JSON.

```jsonc
{
  "schema": 1,                    // integer; bump on any breaking field change
  "kind": "asm-analysis/bundle",
  "corpus": {
    "id": "…", "title": "…",
    "contract": "…",              // one line: what is in scope, and what is NOT
    "variantCount": 3,            // declared width; compared against the array, §4
    "correspondence": { "autoLink": ["file","line"] },
    "relevance": "overlay",       // "overlay" | "cited" | "declared" — see §7
    "contextLines": 3,            // context rows shown around a relevant row
    "tokenFamilies": {            // optional, §7; absent means no token colouring
      "order": ["…"],             // the fixed ordering hues are assigned from
      "aliases": {"…": "…"},      // spelling -> family
      "classes": {"…": "gpr"}     // family -> chroma class
    },
    "generatedAt": "…", "generator": {"name":"…","version":"…","commandLine":"…"},
    "toolVersions": {"objdump":"…","addr2line":"…"},
    "digest": "sha256:…"          // the corpus digest, §9
  },
  "strings":    { "file": [ … ], "function": [ … ], "text": [ … ] },  // §4 Interning
  "variants":   [ … ],
  "units":      [ … ],
  "containers": [ … ],
  "sources":    { "<variant>": { "<file>": … } },
  "stats":      { … },
  "validation": { … },
  "overlay":    { … }             // optional
}
```

**`variants[]`** — one per column.

| Field | Purpose |
|---|---|
| `id`, `label`, `order` | identity, display name, presentation order |
| `axes{}` | free-form axis name → value (`{"shape":"unrolled","compiler":"gcc-13","opt":"-O3"}`). Drives generic faceting and grouping. |
| `caps{}` | **capability facts** the UI may test. Never test a variant `id`. |
| `baseline`, `archived` | roles, as booleans |
| `language`, `compiler`, `flags[]` | provenance for the reader |
| `sourceRev`, `sourceDirty`, `sourceHash` | the authored inputs this column was built from |
| `artifactPath`, `artifactHash`, `artifactKind` | the sealed built artifact |
| `buildCommand` | the exact command |
| `style{}` | optional colour override; otherwise assigned by `order` |

**`units[]`** — `id`, `title`, `description`, `order`, and `realizations{}` mapping
variant id → `{status, file, startLine, stopLine, qualityCounters{}}`.

`status` is one of `present`, `inlined-away`, `absent`, `not-applicable`.
**`not-applicable` is a first-class value, not an absence**: a unit that genuinely
does not exist in one variant renders as an explicit empty panel so the N columns
stay aligned and no unrelated code is ever substituted to fill the gap. This is a
correctness property, not cosmetics.

**`containers[]`** — always a list; never assume one per variant.

```jsonc
{ "id": "ct|1|…", "variant": "…", "name": "…", "displayName": "…", "aliases": ["…"],
  "start": "0x6900", "stop": "0x6dbd", "size": 1213, "zeroSizeFallback": false,
  "chapter": "carrier",                     // 'carrier' | 'unit:<id>' | 'support'
  "instructionCount": 287, "observedCount": 252,
  "unitOccurrences": { "<unit>": [ {"startIndex":586,"stopIndex":594,"observedCount":0} ] },
  "rows":    [ … ],
  "regions": [ … ] }
```

**A low row.**

```jsonc
{ "key": "lo|1|asm|…", "address": "0x699b", "offset": 155,
  "bytes": "4c 8d 24 52", "text": 812,          // internable: string or strings.text index
  "normalized": "lea R64,[R64+R64*2]", "shape": "lea R64,[MEM]",
  "frames": [ {"function":14,"file":3,"line":493, // internable: strings.function/.file
               "displayFunction":"…","key":"hi|1|…","discriminator":null,"physical":false} ],
  "units": ["find_batch","pop_find_queue"],
  "observed": {"executions":12700,"samples":50} }
```

Three fields carry most of the weight:

- **`frames` is a stack, retained whole and never deduplicated.** Collapsing it at
  extraction time destroys "this row is the inlined body of X, called at Y", which is
  most of what an analyst wants in optimized code, and it is irrecoverable. The last
  frame is the enclosing real subprogram and carries `physical: true`; its `line` is a
  declaration site, not a call site. Adjacent repeated functions are legitimate under
  nested inlining — display them verbatim.
- **`offset`** (bytes from container start) is what makes re-anchoring possible after
  a rebuild (§9). Absolute addresses move; offsets usually do not.
- **`unitOccurrences`** bridges physical containers and logical units: contiguous
  index ranges belonging to a unit. Unit navigation scrolls to these, and the region
  markers render from them.

### Interning

A frame stack is the bulk of a bundle, and its strings are almost entirely repeats.
Any field marked internable — a frame's `function` and `file`, a row's `text` — may
hold **either a literal string or an integer index** into the matching array in
`strings`. JSON's own types tell them apart, so small corpora stay readable by hand
and large ones stay small; a consumer needs one resolver.

This is not a micro-optimization. Measured on the reference bundle: 40,522 low rows
carrying 291,646 frames occupied **64.3 MB** because 83 distinct file paths were
written out 291,646 times. Interned, the same data is **6.1 MB** — 10.5× smaller raw,
2.7× gzipped, 151 bytes per row instead of 1,587. A project that skips this concludes
its corpus is too big for JSON when what is too big is its encoding.

**Store no fact twice.** The same bundle also carried an absolute `location` string on
every frame beside the `file` and `line` that already said it — 26.7 MB of pure
restatement. A field derivable from two others is not a convenience, it is a second
copy that can disagree with the first.

**A region** — a folded run of low rows sharing an inline-frame suffix:
`{level, startRow, stopRow, rows, function, displayFunction, atFile, atLine,
calledAtFile, calledAtLine, fragment:[k,n]}`. `fragment` says how many pieces the
compiler cut one inlined function into, which is often the finding itself.

**`sources`** — the authored text, embedded, so the bundle is self-contained.
Per variant, per file: `{available, lineCount, contentHash, checksum, lines:[{n,text,relevant}]}`.
`available: false` is a first-class value rendered as an explicit placeholder, so
columns stay aligned. `checksum` is the debug-info's own per-file source checksum
where the format provides one — see §9, this is what turns a revision pin into proof.

**`stats`** — per variant: instruction counts, per-file and per-depth histograms,
counts for any declared hot region. Recompute from the bundle; never hand-copy a
number into a report.

### Invariants

The build fails loudly unless all of these hold. Each is cheap and each catches a
real cross-build error.

| Invariant | Catches |
|---|---|
| declared cohort width equals `len(variants)` | truncated or hand-edited bundle |
| every unit appears in every variant (possibly `not-applicable`) | column misalignment |
| every key is well-formed and its components round-trip | key-constructor drift |
| no address appears in two containers | overlapping or duplicated ranges |
| addresses within a container are strictly monotonic and unique | decode range error |
| decode covers exactly `[start, stop)` | symbol/decode disagreement |
| every frame's `file`/`line` resolves inside a known source file | wrong source revision |
| static artifact hash **equals** overlay artifact hash | measuring a different build |
| observed address set **equals** the accepted measurement set | partial or superset overlay |
| overlay bytes at each address equal the decoded bytes | decode/measure disagreement |
| the contract string matches across all inputs | mixing incompatible measurement scopes |
| re-running the builder produces a byte-identical bundle | nondeterminism |

Equality of **sets**, not subset containment, is load-bearing in the overlay rows. A
subset check passes happily on an overlay quietly missing half its data.

## 5. The annotation store — authored, in git

Authored data cannot be regenerated, only migrated. Keep it as deterministic text in
the project repo, separate from the bundle, joined **only by key string** at render
time. The bundle holds no annotation; the store holds no code. A key with no bundle
row is invisible; a bundle row with no key match is unannotated. Neither is an error.

```
annotations/
  tags.json            the controlled vocabulary
  equivalences.json    authored cross-variant groups
  chunks.json          the work partition (§8)
  adjudications.json   decisions on contested proposals, with the dissent
  notes/<chunk>.<variant>.json
```

Serialize deterministically — sorted keys, one record per line where practical — so a
diff shows the judgement that changed and a review can be a normal PR.

**`tags.json`** — `{schema, tags:[{id, label, color, kind, note, match?}]}`.
`kind` is `instruction`, `source`, or `component`. `match` is an optional automatic
rule (a regex over row text, or a declared region predicate); a tag with a `match`
that selects zero rows is a **refusal**, because it is a rule that has rotted.

**`equivalences.json`** — `{schema, groups:[{id, note, members:[highKey], memberHashes:{}}]}`.
A group needs at least two members and a `note` saying what step of the algorithm all
members express. One key belongs to at most one group; two groups claiming one key is
a refusal. `memberHashes` records each anchored line's text hash at authoring time so
drift is detectable (§9).

**`notes/<chunk>.<variant>.json`**

```jsonc
{ "schema": 1, "chunk": "cursor-state", "variant": "inline",
  "artifactHash": "sha256:…",
  "notes": { "0x43cc0c": { "body": "…", "confidence": "high",
                           "container": "find_batch", "offset": 12, "bytes": "83 c2 01",
                           "evidence": ["…"] } },
  "omissions": { "0x43cc10": "Alignment NOP only; no separable semantic fact." } }
```

`container`, `offset` and `bytes` are **mandatory** — they are what makes the note
re-anchorable after a rebuild. `confidence` is `high` or `medium` only: there is no
`low`, because an uncertain note is an omission. Every owned address carries a note or
an omission; omission means *no separable semantic fact exists*, never *I am unsure*.

### Rules

- **Never write on read.** Opening the viewer must not create, repair or seed
  anything. Curated state that changes with how often the UI was opened is not data.
- **Curation is transactional.** An equivalence edit is opened on an anchor, toggled
  freely, and committed by an explicit action; cancel or navigate-away writes nothing.
  Removing a member from the anchor's group makes that member ungrouped; selecting a
  member of another established group merges that group's *complete transitive*
  membership, preserving the meaning of what was already saved.
- **Conflict is a value.** When records disagree, keep every distinct one, mark the
  row `conflict`, render it in the danger colour, and let the analyst resolve it by
  saving an override. Never silently narrow an ambiguous fact.
- **Legacy keys are read forever and never rewritten in place.** A row inherits
  annotations found under keys it could previously have been named by. Keep
  *annotation* inheritance (notes and tags always display) separate from *mapping*
  inheritance (a legacy override applies only if no current override exists) —
  merging the two channels loses tags on rows that never had a mapping record.
- **Keep a canonical manifest hash.** Sort each group's members, sort the groups,
  serialize, hash. It is independent of group ids, so it survives renumbering, and it
  answers "did this operation change any curated meaning?" with one comparison. Build
  it on day one; it is what lets an unrelated write be *proved* harmless.

## 6. Instantiating the equivalence data

A process, per toolchain. Stages are additive and each is separately rerunnable.

**A · Build.** One artifact per variant, with debug info *and* optimization on — the
whole point is what the optimizer did. Hold everything fixed except the axis under
study, and record the exact command. Two rules that cost real time when missed:

- **Request the debug format that carries per-file source checksums**, and verify they
  are present. This is the only mechanical proof that the source you display is the
  source that was compiled (§9).
- **Read provenance from a linked image, not a relocatable object.** In a `.o` every
  function sits at section-relative zero, so inline frames cannot be disambiguated —
  which is the entire basis of the mapping. If you disassemble the object to keep a
  decode from overrunning into the next function, do that separately and reconcile.

**B · Enumerate containers.** From the symbol table or the toolchain's own listing.
Refuse on an ambiguous match, a zero match, or overlapping ranges that are not exact
aliases. Record an inferred bound (a zero-sized symbol extended to the next) as a flag
in the artifact rather than silently.

**C · Decode.** Disassemble each container's exact range. Normalize the decoder's
quirks *once*, here — long encodings wrapped onto continuation lines are the classic
one, and naive line-counting has produced wrong instruction counts in both reference
projects. Verify the decode covers exactly the declared range.

**D · Attribute.** Get the full provenance stack per row, batched. Keep it whole
(§4). Verify the tool returned exactly the addresses asked for, no drops and no
duplicates — a silent omission here is invisible later.

**E · Resolve paths.** Map recorded paths to project-relative ones through a declared
alias table, each entry stating its origin: read from the version-control revision, or
read from disk (toolchain headers, generated files). A path matching no rule is
`available: false`, not a crash. Record a content hash per file.

**F · Fold regions.** Identify an inline instance by its *ancestor* frames' `(function,
line)` pairs plus its own function name — the ancestors are call sites and part of the
identity; the row's own line moves within the instance. Maximal contiguous runs with
equal identity become regions; count instances to assign `fragment [k,n]`.

**G · Attribute units.** A row belongs to a unit if **any** frame falls inside that
unit's declared range. A row may belong to several — that is what inlining means, so
keep the set whole. Fold contiguous same-unit runs into `unitOccurrences`.

**H · Validate and emit.** Run §4's invariants, then serialize deterministically.

### Refuse, do not warn

Every check above is a refusal that stops the build. A warning is a check nobody
reads. The exceptions worth allowing are narrow and should be stated: a *component*
tag matching zero rows is legitimate (some lines appear only as outer call-site
frames), while an *instruction* tag matching zero rows is a rotted rule.

Write **negative tests**: copy the tree to a temporary directory, corrupt one input,
and assert the specific refusal fires. A refusal nobody has seen fire is a refusal
that does not work.

### Mapping quality is a number

Emit counters per unit and per variant: rows mapped, rows unassigned **bucketed by
why**, source-order backtracks, fragmented statements. Put them in the bundle. This is
how a degraded heuristic is discovered — the alternative is an impression from
scrolling, which arrives months late.

### The three layers of correspondence, kept separate

They have different trust levels and must never be blended into one number.

1. **Identity** — two high rows that auto-link under `correspondence.autoLink`. Free,
   mechanical, covers every shared helper.
2. **Frame containment** — a high row lights every low row whose frame stack contains
   its key, and a low row lights all of its frames' lines. Pure provenance, no
   curation.
3. **Curated equivalence** — authored groups. The only thing that can connect bodies
   which share no source line, and the only correspondence the system calls truth.

Automatic cross-variant *alignment* (fuzzy matching of statements by normalized text
and instruction shape) is a fourth, **advisory** layer. Ship it as a suggestion that
seeds curation, labelled with its confidence tier, and never as an answer. If you
build it: normalize away register allocation, stack layout and branch targets; score
generic statements (`}`, `return;`, fewer than two tokens) at zero unconditionally;
preserve order so matches cannot cross; and prefer false negatives — pairing unrelated
control transfers is worse than pairing nothing.

## 7. The viewer

### Layout law

**One CSS grid owns every panel: 2 rows × N columns.** Row 1 is the authored
representation, row 2 the generated one. Panels never scroll horizontally; the
workspace does — exactly one horizontal scroller is what keeps all 2N panel boundaries
aligned, and per-panel horizontal scrolling silently destroys the alignment the
workspace exists to provide.

- Column count is a CSS custom property set from the bundle at startup. Any literal
  cohort count in the stylesheet is a pre-script fallback only.
- Column width is a **floor**, with `1fr` sharing surplus so a wide display fills.
- Render hosts use `display: contents` so they add no layout box; panels get
  `contain: layout paint size`.
- The client compares the bundle's declared width against the array length and throws
  on disagreement. A truncated bundle must fail loudly, not render short columns.

Panel anatomy: head (label · provenance · selector · match count) / body (the only
vertical scroller) / overview rail beside the scrollbar. Give the high panel the same
selector affordance as the low one: a unit's authored text may span several files, and
assuming one file per unit is the assumption that breaks first in a new project.

Tunables, not laws — say which is which in the code, because the next reader cannot
tell: the pin cap (a legibility budget), the row-height split between the two bands,
the context window, the overscan depth. The laws are one grid, one horizontal
scroller, declared width, and row height having a single source of truth.

### Two tiers in the high panel

Rows are **relevant** (full opacity) or **context** (dimmed, ±N lines). What makes a
row relevant is declared by `corpus.relevance`: `overlay` (measured as executed),
`cited` (some low row maps to it), or `declared` (an explicit list). Same grammar
either way — a project without a profiler is not a different UI.

### Virtualization

Not an optimization, a precondition — and it must exist **before** highlighting is
written, because matches scrolled out of the window have no DOM node to colour.
Retrofitting means rewriting the highlighting.

- Row height is a single source of truth. Pin the script's constant to the stylesheet's
  custom property with a test; two copies drift.
- Region markers occupy row slots in the same virtual model as rows, so **instruction
  index ≠ row index**. Keep an explicit index-translation map and always translate.
  Using the instruction index as a row index is correct until the first marker and
  progressively wrong after it.

### Two selection axes

| | Correspondence | Classification |
|---|---|---|
| Subject | one high-row key, expanded through equivalence | a set of tag ids |
| Interaction | hover (transient) and pin (sticky, capped) | a filter panel, uncapped |
| Scope | both rows, all N columns | low rows, all N columns |
| Precedence | wins | yields |

Expansion is the N-way operation: a hover in one column unions the hovered key's
equivalence group and lights every match in all 2N panels.

**Expand the innermost frame across columns, not the whole stack.** The full stack may
light within the hovered column, but seeding cross-column expansion from every frame
makes the hovered column dominate and the comparison the tool exists for stops
working. Which key a low row seeds should prefer the unit currently being viewed.

**Pinned selection has two tiers**: *seeds* (what was clicked, solid) and *partners*
(curated group members that were not clicked, dotted) — because a partner is a claim
the store makes, not a fact from provenance, and the reader should see which is which.
Clicking a partner **adds** it; the inherited "click any member to unpin the set" rule
makes a partner impossible to adopt.

Two invariants, both worth testing:

- Selection state holds **keys, never DOM nodes**.
- A selection change **mutates classes in place and never re-renders**. Repainting
  destroys the node under the pointer, fires `pointerleave`, and the hover flickers
  off.

Gate expensive work (rails, which force layout by reading offsets) on a selection
signature so it runs once per change, not once per pointer move.

### Overview rails

Project every match onto a narrow rail beside each panel's scrollbar, so a match in a
container scrolled far out of view is still locatable and clickable. Two lanes —
correspondence on one side, classification on the other. Positions are **fractions of
scroll range**; clamp sub-pixel marks to a visible minimum and merge adjacent marks
only **within one colour**, since merging across colours invents a colour no row has.

### Colour

Four independent channels, and an explicit precedence between them: hover, pinned,
frame-stack, and group-partner beat context dimming and the tag tint; the tag tint
does not use `!important`, so a tagged row reads as hovered while hovered and reverts
to its tag colour afterwards. **Dimming must always yield to a highlight** — context
dimming that can suppress a match is a correctness bug.

Define semantic custom properties (`--linked`, `--pinned`, `--stack`, `--group`,
`--warning`, `--danger`) once and theme by overriding them. Give both light and dark a
complete definition.

**Variant colours follow `experiment-infrastructure`'s family hue order**, so a
variant is the same colour in the workspace and in every plot of the same study.

**Token families** — colour operand tokens by the entity they name, not by spelling:
canonicalize to the family (all widths of one register are one entity) and assign hue
from a **fixed table**, never encounter order, so a token keeps its colour across
panels and rebuilds. Over a known, small set, divide the circle evenly on a stride
coprime with the count rather than using the golden angle, which leaves visible
collisions at small N; keep the golden angle for open-ended sets. Pin lightness in a
perceptual space, vary chroma by class, and mute tokens that name an addressing base
rather than a computed value. Prove the result: sweep every hue against every row
background the stylesheet can produce and assert a contrast floor.

### Navigation

- Container and unit are independent axes. Selecting a unit changes which container is
  shown and where it scrolls — **never** which rows a container contains. A container
  always shows all of itself.
- A jump is not a selection: move the viewport and flash the anchor; leave pins and
  filters untouched.
- Remember scroll position keyed by `(variant, container)` and `(variant, unit)`, not
  per DOM element.
- Make every line number and address a control that yields a copyable stable
  reference, so a finding can be cited in prose and found again.
- Search units by id, title, description **and the full authored text of every
  variant**.

Keyboard: previous/next unit, next/previous fragment, pin, clear, find, align pinned
rows to the top, toggle the tag panel. Suppress shortcuts while an input or dialog has
focus. Low rows are focusable with a label combining address, text and state; use
native dialogs.

### Contract tests

Assert the layout and architecture contract as **string assertions over the HTML, CSS
and JS sources**: that the column count is read from a custom property and no literal
cohort count appears; that the script's row height equals the stylesheet's; that the
named highlighting functions exist; that removed spellings appear nowhere. These are
properties no unit test reaches and a browser test reaches only slowly and flakily,
and they are exactly what a plausible-looking edit breaks quietly. Make the failure
message name the invariant, so the test documents why the rule exists.

## 8. Dividing the corpus into work chunks

Annotation is the expensive half. Partition it so that work is parallel, reviewable,
and never silently redone.

**Partition, do not sample.** Every low row carrying a reviewed attribution belongs to
**exactly one** chunk. Principal units own the helpers inlined into them; direct
helper occurrences own themselves; residual code belongs to its enclosing container's
chunk. Chunks may span non-contiguous ranges and should carry wider read-only context.

**Size a chunk by what fits one sitting**, not by structure — the references settled
near 40–150 rows, and batched by byte budget where a whole chunk had to fit one
prompt. One chunk per `(chunk, variant)` pair keeps files small and merges clean.

**Order chunks into dependency-gated phases.** A later phase refuses to start until
its predecessors are approved. The reference ordering generalizes: establish
terminology and structure layout on the *simplest* variant first, then the variants
that differ from it, then the ones whose reading depends on authored equivalence. Say
explicitly what may cross a phase boundary — a hypothesis about intent may; a concrete
register assignment or a field offset may **not**.

**A chunk manifest is generated, pinned, and gitignored.** It carries the chunk id,
phase, target variant, the artifact hash, the source range and its keys, the owned
addresses, the context ranges, the existing notes, the equivalence members relevant to
its lines, and a `provenance` block hashing the bundle it was generated from. Generate
with a `--check-only` mode, and **refuse to run when the bundle has moved**: old
manifests and old approvals are stale even when the addresses look similar.

**Ship ground truth with the brief, so annotators do not guess.** Derive the actual
structure layouts, field offsets, constant values and entry conventions *from the
built artifact* and include them — they are facts about this build, not about the
headers as they read today. State known traps: a variant with disjoint fast and slow
regimes has no single register map, and the same name may live in different registers
in two copies of one loop.

**Separate the analyst from the verifier.** One agent (or person) writes the analysis
and proposed notes; a **different** one re-derives the facts from the artifact and
writes the approval. Approvals are immutable artifacts. Put the stronger reviewer on
*analysis*: across the reference's ~58 verifications essentially every rejection was
an analyst error — analysis is the hard half.

**A note must answer, in order and only where applicable:** which register or slot
holds which named thing; what a memory operand's base is and what its offset names
(the field name and type, not "offset 0xb4"); and what the instruction does with it in
the *source's* vocabulary. "Moves a dword" is worthless.

**Merging proposals has three outcomes, never last-writer-wins.**

| Outcome | When | Action |
|---|---|---|
| **applied** | the proposal touches nothing already claimed | merge |
| **conflict** | two chunks claim one row differently | **refuse** — a real disagreement, resolved by reading |
| **contested** | the proposal contradicts an existing claim | not applied; requires adjudication |

Record every adjudication **with its dissent** — the call, the reasoning, and declined
proposals too, so the same argument is not re-litigated from scratch. Rewrite
co-dependent files (the vocabulary and the groups) **together**; letting them drift
passes every single-file check while the two disagree about what a row means.

**Merge by replaying immutable approvals, never by copying a file.** Stage, merge,
compare the staged store against production as a strict superset, review visually,
then replay the *same* approval artifacts into production. Back up first, use one
transaction, verify row counts and integrity before committing.

**Compute progress; do not track it by hand.** A coverage report derived from the
bundle and the store — per chunk, per variant: owned rows, noted, omitted, state —
cannot go stale. **Completion is not note count**; it is verified semantic coverage
with explicit uncertainty. Leaving a row deliberately unclaimed is a fine outcome when
the reason is recorded.

## 9. Keeping it current

The bundle is derived and disposable. The store is authored and only migratable.
Everything here protects the second from changes to the first.

**Corpus digest.** Hash a deterministic file set that includes the *tooling and
environment*, not just the data: the manifest, the extractor and validator sources,
the build entry point, and the dependency lockfile. Each file contributes its relative
label and its bytes. Record the digest in the bundle.

**Reuse a validation record only on an exact match** of pass/fail, cohort, and digest,
and when it does not match, print the specific reason. Silently accepting a stale
record is how a bundle built outside the pinned toolchain survives a whole cohort
change unnoticed.

**Prove the source pin; do not declare it.** A revision pin that is merely *declared*
fails in the worst way: a wrong revision with identical line *numbering* passes every
structural check, and the display then shows source that was never compiled. Both
reference projects hit this, and in one case a single line differing only in content
— a constant — was caught by a human reading both sides, not by any check.

- Require the debug format's **per-file source checksum**, compare it against the
  file you are about to display, and refuse on mismatch. This turns the pin into a
  proof and is the single most valuable check to add.
- Where the toolchain cannot provide one, say so in the bundle and in the UI, and
  compare content hashes against the revision you claim.
- Display the revision and the file counts in the panel head, so the assumption is
  visible rather than buried.

**Rebuild strands low-row annotations, and that is correct** — the annotation was
about instructions that no longer exist. Refuse rather than re-anchor silently: a note
file whose recorded artifact hash does not match the bundle's must stop the build with
a message saying to re-anchor, never to edit the hash.

**Re-anchoring is a distinct, explicitly-invoked job**, never a side effect:

- match by **(container, offset, bytes)**, not absolute address;
- require **byte-identical** rows before relocating anything;
- report every note it could not place, and place nothing it is unsure of.

The cheap insurance is to keep the bundle **tracked in git at the commits where
curated work happened**, so a future re-anchor has a ground truth to recover offsets
from. This is the one good reason to version-control a large generated file.

**Migration playbook**, in order:

1. **Scan for key spaces; do not assume them.** The reference migration was briefed
   with four and found five.
2. **Enumerate renames versus retirements.** A rename is the same artifact under a new
   name. A retirement is a differently-built successor. **A retirement is not a
   rename** — carrying row-keyed annotations onto a successor points them at the wrong
   rows, silently. When in doubt, retire.
3. **Quarantine rather than delete**, preserving original ids and timestamps, and copy
   the vocabulary so moved assignments still resolve to names.
4. **Predict counts, then refuse on mismatch.** This is the check that catches the key
   space you missed.
5. **Default to dry-run**; writing takes an explicit flag.
6. **One transaction**, integrity checks before commit, and compare the canonical
   manifest hash across the boundary for whatever must not change.
7. **Be idempotent** — a second run detects canonical state and writes nothing.
8. **Write the migration document as you go**: what moved, counts before and after,
   the non-obvious calls *and why*, what is still broken, and the exact restore
   commands.

**Expect degradation, not loss.** After a cohort change, curated correspondence is
degraded: most groups lose a member, some empty out, some are left with a single
member. Keep one-member groups as they are — meaningless but harmless — and recover by
a reviewed re-seed, not by hand-patching. Say this in the migration document rather
than leaving a reader to infer it from row counts.

**State what the artifact cannot support.** Carry the permanent caveats in the bundle
and show them in the UI: line-granular provenance does not justify expression-level
claims; a static range is not an execution trace; an instruction count at a hot spot
is not a per-operation cost; artifacts built for the host machine are comparable only
against others built the same way. Say which footing any number came from.

## 10. Build order

Attempted in another order these stages fight each other.

| # | Stage | Acceptance check |
|---|---|---|
| 1 | **Identity.** Key constructors and their tests, nothing else. | round-trip and normalization tests pass; every space is namespaced and versioned |
| 2 | **Extractor.** Containers, decode, provenance, one output per variant. | re-running is byte-identical; every refusal fires on a deliberately corrupted input |
| 3 | **Bundle.** Assemble, validate, emit deterministically. | §4's invariants enforced; a truncated bundle fails loudly |
| 4 | **Static 2×N grid.** All panels, no virtualization, one small container. | no overlap from 480px up; exactly one horizontal scroller |
| 5 | **Virtualization.** Row model, paint window, index map, markers. | the last row of the largest container lands exactly, not off by the marker count |
| 6 | **Tracing.** Hover and pin, both directions. | a hover in each column lights the same set; no flicker on a slow pointer sweep |
| 7 | **Store.** Files, load, save, notes, tags. | a write leaves the canonical manifest hash unchanged |
| 8 | **Rails, counters, tag axis.** | a match scrolled out of view is locatable and clickable; a tagged and pinned row shows both |
| 9 | **Curation.** Equivalence editing, then proposal passes. | cancel writes nothing; a pass over reviewed keys reports skips and writes nothing |
| 10 | **Contract tests, export, migration tooling.** | §7, §9 |

**Identity before anything persists**, and **virtualization before highlighting**, are
the two orderings that matter most.

Export, when it exists: label mapping provenance on every row so a reader can tell
curated from derived, and **never drop unmapped evidence** — an export that silently
omits what it could not place is the one that misleads. It is fine for an export to
lag the interactive model; say so where it is invoked.

## 11. Anti-patterns

Each of these is a regression these designs actually absorbed.

- **Hardcoding the cohort** — any constant naming a variant, or counting them, in the
  client.
- **Two sources of truth for row height**, drifting between script and stylesheet.
- **Using the instruction index as the row index.**
- **Repainting to update highlights.**
- **Expanding every provenance frame across columns on hover.**
- **Collapsing the provenance stack at extraction time.** Irrecoverable.
- **Letting a page load write.**
- **Silently picking a winner among conflicting records.**
- **Subset checks where set equality is meant.**
- **Comparing rendered text instead of bytes** for overlay identity. False alarms
  train everyone to ignore the check.
- **Per-panel horizontal scrolling.**
- **Dimming that can suppress a match.**
- **Treating a retirement as a rename.**
- **Ignoring a stale validation record.**
- **Assuming one container per variant**, or indexing the first one.
- **Hardcoding a revision in a query tool** instead of reading it from the bundle —
  that is how a stale pin survives a re-pin.
- **Counting decoder output lines naively.** Wrapped encodings are not instructions.
- **Writing a frame stack out longhand.** The strings are near-all repeats; it inflates
  a bundle roughly 10× and gets the format blamed for the size.
- **Storing a fact twice** — an absolute location beside the file and line that derive
  it. Two copies that can disagree, and in the reference it was a third of the bundle.

## Helper script

`asmviz` (this directory, Python 3, standard library only, no dependencies):

```sh
asmviz check  <bundle.json> [--annotations DIR]   # schema + §4 invariants + store consistency
asmviz stats  <bundle.json>                       # counts, coverage, mapping-quality counters
asmviz chunks <bundle.json> --by unit|container|file [--size N]   # propose a partition (§8)
asmviz serve  <bundle.json> [--annotations DIR] [--port N]        # reference 2×N viewer
```

`serve` renders the workspace described in §7 from any conforming bundle and writes
annotations back as the deterministic text of §5. It is a reference consumer of the
format, not project code — a project should emit a bundle and use it, and only fork it
when it needs something the format cannot express. When that happens, extend the
format and this skill rather than the fork.
