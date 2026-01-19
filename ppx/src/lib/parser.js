#!/usr/bin/env node
// CSS class name extractor for rescript-typed-css-ppx
// Based on rescript-typed-css-modules generation logic

const fs = require("fs");
const postcss = require("postcss");
const postcssImport = require("postcss-import");
const postcssModules = require("postcss-modules");
const postcssScss = require("postcss-scss");

// Parse command line args
const inputPath = process.argv[2];
const outputPath = process.argv[3];

if (!inputPath || !outputPath) {
  console.error("Usage: parser.js <input.css> <output.txt>");
  process.exit(1);
}

const css = fs.readFileSync(inputPath, "utf-8");

postcss([
  postcssImport(),
  postcssModules({
    getJSON: (_, json) => {
      // Extract class names and sort them alphabetically
      const classNames = Object.keys(json).sort();
      fs.writeFileSync(outputPath, classNames.join(","));
    },
    // Export :global() classes too
    exportGlobals: true,
  }),
])
  .process(css, { from: inputPath, syntax: postcssScss })
  .then(() => {})
  .catch((err) => {
    console.error("Error processing CSS:", err.message);
    process.exit(1);
  });
