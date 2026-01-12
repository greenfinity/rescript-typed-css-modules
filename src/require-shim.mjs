/*

# The Problem

The `@greenfinity/rescript-typed-css-modules` package provides a CLI tool (`css-to-rescript`) that generates ReScript bindings from CSS module files. This tool depends on `postcss`, `postcss-modules`, and `postcss-import` for parsing CSS.

**Goal**: Bundle ALL dependencies into a single executable file, so consuming projects don't need to install postcss (or Rescript core libraries)as a dependency. They just install the package and run the CLI.

# The Challenge

1. **ReScript compiles to ESM** - The `.bs.mjs` files use `import.meta` and ES module syntax, requiring `--format=esm`
2. **postcss uses CommonJS** - It has dynamic `require()` calls that don't work in ESM bundles
3. **These two requirements conflict** - ESM bundles can't handle CommonJS `require()` calls

# The Solution

Use `createRequire` to provide a working `require` function in the ESM bundle.

**esbuild command**:

```bash
esbuild src/CssToRescript.bs.mjs \
  --bundle \
  --platform=node \
  --format=esm \
  --outfile=dist/css-to-rescript.js \
  --banner:js="#!/usr/bin/env node" \
  --inject:./src/require-shim.mjs
```

Key flags:

- `--bundle` - Bundle all dependencies into one file
- `--platform=node` - Target Node.js runtime
- `--format=esm` - Required because ReScript outputs ESM
- `--inject:./src/require-shim.mjs` - Inject the shim at the top of the bundle, providing `require` for bundled CommonJS code

# Why --inject instead of --banner

Initially tried putting the shim code in `--banner:js`, but shell interpretation in package.json scripts caused errors with newlines. Using `--inject` with a separate file avoids shell escaping issues.

*/

import { createRequire } from 'module';
globalThis.require = createRequire(import.meta.url);
