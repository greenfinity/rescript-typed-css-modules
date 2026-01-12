# rescript-typed-css-modules

Generate type-safe ReScript bindings from CSS Modules (`.module.css` / `.module.scss`) and global CSS (`.global.css` / `.global.scss`).

Only tested with Next.js and might not work with other frameworks out of the box.

## Features

- Extracts class names from CSS/SCSS module and global files
- Generates a typed record for all class names
- Supports `@import` rules (imported classes are included in the generated bindings)
- Also enable access to non-scoped classes (e.g. `:global()` classes)
- Supports type-safe access to global css classes (`.global.css` / `.global.scss`)
- Supports recursive directory scanning
- Watch mode for automatic regeneration on file changes
- Process multiple files or directories in a single command

## File naming conventions

| Input file                       | Generated binding |
|----------------------------------|-------------------|
| `*.module.css` / `*.module.scss` | `*_CssModule.res` |
| `*.global.css` / `*.global.scss` | `*_GlobalCss.res` |

### Why global CSS support?

The use case is to access classes in a type safe way from third party css libraries, that emit HTML markup with predefined class names without the use of css modules (e.g. React Aria Components).

Global CSS files (`.global.css` / `.global.scss`) also get type-safe bindings, but they are not imported, and their class names are **not hashed**. This is useful when working with third-party libraries (such as React Aria Components) that emit HTML markup with predefined class names that you need to style.

Even though global CSS classes aren't scoped, generating typed bindings provides the benefit of compile-time checking that class names exist.

The imports are not done because these css typically has to be imported from the top of the component hierarchy. So the import has to be done manually. To get type safe access, simply rename the file to `.global.css` (or create one and import the original css from it).

(Remark: we could also provide a way to import the css automatically, but this would open issues with removing duplicates during bundling, and handling the css on route changes. NextJs does not support these use cases out of the box, so we revert to the manual import for global css.)

## Installation

```bash
yarn add @greenfinity/rescript-typed-css-modules
```

## Usage

```text
Usage
  $ css-to-rescript <file.module.css|scss|global.css|scss...>
  $ css-to-rescript <directory...>

Options
  --watch, -w         Watch for changes and regenerate bindings (directories only)
  --skip-initial, -s  Skip initial compilation in watch mode
  --output-dir, -o    Directory to write generated .res files
                      (multiple files or single directory only)

Examples
  $ css-to-rescript src/Card.module.scss
  $ css-to-rescript src/Theme.global.css
  $ css-to-rescript src/Button.module.css src/Card.module.scss -o src/bindings
  $ css-to-rescript src/components
  $ css-to-rescript src/components src/pages --watch
  $ css-to-rescript src/components --watch --skip-initial
```

## Example

Given a CSS module:

```css
/* Button.module.css */
.btn {
  padding: 0.5rem 1rem;
}

.btn-lg {
  padding: 1rem 2rem;
}

.disabled {
  opacity: 0.5;
}
```

The tool generates:

```rescript
// Button_CssModule.res
// Generated from Button.module.css
// Do not edit manually

type t = {
  "btn": string,
  "btn-lg": string,
  "disabled": string
}
@module("./Button.module.css") external css: t = "default"
```

### Using the bindings

```rescript
<button className={Button_CssModule.css["btn-lg"]}>
<button className={Button_CssModule.css["disabled"]}>
```

You can combine multiple classes with template strings:

```rescript
<button className={`${Button_CssModule.css["btn"]} ${Button_CssModule.css["btn-lg"]}`}>
```

### CSS imports

The tool supports `@import` rules. Imported classes are included in the generated bindings:

```css
/* shared.css */
.shared-class {
  color: red;
}
```

```css
/* WithImport.module.css */
@import "./shared.css";

.local-class {
  background: blue;
}
```

Generates:

```rescript
// WithImport_CssModule.res
type t = {
  "local-class": string,
  "shared-class": string
}
@module("./WithImport.module.css") external css: t = "default"
```

### Global CSS

For third-party libraries that emit HTML with predefined class names (e.g. React Aria Components), you can create a `.global.css` file to get type-safe bindings without CSS Modules scoping:

```css
/* Theme.global.css */
.dark-mode {
  background: #1a1a1a;
}

.light-mode {
  background: #ffffff;
}

.primary-color {
  color: blue;
}
```

Generates:

```rescript
// Theme_CssGlobal.res
type t = {
  "dark-mode": string,
  "light-mode": string,
  "primary-color": string
}

// Class names are returned as-is (no hashing)
let css = ...
```

Usage:

```rescript
// Import the CSS manually at your app root
%%raw(`import "./Theme.global.css"`)

// Then use type-safe class names anywhere
<div className={Theme_CssGlobal.css["dark-mode"]}>
```

## How it works

1. Parses CSS/SCSS files using PostCSS to extract class names
2. Generates a typed record `css` containing all class names, accessible via string keys.

## Caveats

This tool generates bindings that assume CSS Modules are processed by a bundler with CSS Modules support. Currently tested with Next.js, which applies PostCSS module transformation automatically.

If using outside of Next.js, you may need to configure your bundler (Vite, Webpack, etc.) to handle CSS Modules scoping. This has not been tested outside of Next.js.

## Requirements

- Node.js >= 22.12.0
- ReScript >= 12.0.0

## License

MIT
