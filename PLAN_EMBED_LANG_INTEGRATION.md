# Plan: Integrate rescript-typed-css-modules with ReScript Build System

## Research Summary

### rescript-embed-lang
**Not suitable.** It only does PPX string replacement - you still need a separate watch process for code generation. No build system integration.

### Rewatch Native Generators
**Not yet available.** There's an [open specification (issue #127)](https://github.com/rescript-lang/rewatch/issues/127) describing how rewatch would natively support generators:

- Configure generators in `rescript.json`
- Compiler outputs `.embeds` files with embedded content
- Rewatch invokes generators automatically during build
- Caching via source hashes

However:
- The [compiler PR #6823](https://github.com/rescript-lang/rescript/pull/6823) was **closed** (Sep 2025) - "needs a full reboot"
- No implementation PRs linked to the rewatch issue
- Recent rewatch releases (up to v1.2.2) have no generator features

**Status: Designed but not implemented.**

---

## Options

### Option A: Wait for Rewatch Native Generators

Wait for the rewatch team to implement the generator spec.

**Pros:**
- First-class integration
- No separate watch process
- Automatic caching

**Cons:**
- Unknown timeline
- Feature may never ship

### Option B: Contribute to Rewatch

Implement the generator spec ourselves and contribute upstream.

**Pros:**
- Makes it happen
- Benefits the whole ecosystem

**Cons:**
- Significant effort (Rust codebase)
- Need to coordinate with maintainers
- May need compiler changes too

### Option C: ReScript Plugin/PPX Approach

Create a PPX that runs at compile time and generates the bindings inline.

**Pros:**
- Works today
- No separate process
- Integrated into ReScript build

**Cons:**
- PPX runs on every compile (though could cache)
- More complex than code generation

### Option D: Keep Current Approach

Continue with the current CLI tool, run it before/alongside `rescript build -w`.

**Pros:**
- Already works
- Simple

**Cons:**
- Separate watch process
- Not integrated

---

## Recommendation

**Short term:** Keep current approach (Option D)

**Medium term:** Monitor rewatch issue #127. If it gains traction, prepare integration.

**Long term:** Consider Option B (contribute to rewatch) if the feature stalls but demand exists.

---

## If We Pursue Option C (PPX)

A PPX could intercept `%cssModule("./path.module.css")` and:

1. At compile time, read the CSS file
2. Extract class names
3. Generate the type and bindings inline

This would require:
- Writing a PPX in OCaml/ReScript
- Handling file I/O at PPX time
- Caching to avoid re-parsing unchanged CSS files

**Complexity:** Medium-High
**Maintenance:** Need to keep PPX compatible with ReScript versions
