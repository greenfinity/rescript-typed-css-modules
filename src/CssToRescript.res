// CSS Modules to ReScript converter
// Extracts class names from .module.css/.module.scss files and generates ReScript bindings

module Node = {
  module Fs = {
    @module("fs") external readFileSync: (string, string) => string = "readFileSync"
    @module("fs") external writeFileSync: (string, string) => unit = "writeFileSync"
    @module("fs") external statSync: string => {"isFile": unit => bool, "isDirectory": unit => bool} = "statSync"
    @module("fs") external readdirSync: (string, {"withFileTypes": bool}) => array<{"name": string, "isDirectory": unit => bool}> = "readdirSync"
  }

  module Path = {
    @module("path") external basename: string => string = "basename"
    @module("path") external dirname: string => string = "dirname"
    @module("path") external join: (string, string) => string = "join"
  }

  module Process = {
    @scope("process") @val external argv: array<string> = "argv"
    @scope("process") external exit: int => unit = "exit"
  }
}

// ReScript reserved words that need escaping
let rescriptKeywords = [
  "and", "as", "assert", "await", "catch", "constraint", "downto", "else",
  "exception", "external", "false", "for", "fun", "functor", "if", "in",
  "include", "inherit", "initializer", "land", "lazy", "let", "lor", "lsl",
  "lsr", "lxor", "match", "mod", "module", "mutable", "new", "object", "of",
  "open", "or", "private", "rec", "sig", "struct", "switch", "then", "to",
  "true", "try", "type", "val", "virtual", "when", "while", "with",
]->Set.fromArray

// Extract class names from CSS/SCSS content using regex
let extractClassNames = cssContent => {
  let classNames = Set.make()
  let regex = %re("/\.([a-zA-Z_][a-zA-Z0-9_-]*)/g")

  let rec findMatches = () => {
    switch regex->RegExp.exec(cssContent) {
    | Some(result) =>
      // matches returns array where index 0 is first capture group (not full match)
      switch result->RegExp.Result.matches->Array.get(0) {
      | Some(Some(className)) =>
        classNames->Set.add(className)->ignore
      | _ => ()
      }
      findMatches()
    | None => ()
    }
  }

  findMatches()
  classNames->Set.values->Iterator.toArray->Array.toSorted(String.compare)
}

// Convert kebab-case to camelCase
@send external replaceWithFn: (string, RegExp.t, @uncurry (string, string) => string) => string = "replace"

let toCamelCase = str => {
  // Replace -x with X (capitalize letter after hyphen)
  str->replaceWithFn(%re("/-([a-z])/g"), (_, char) => char->String.toUpperCase)
}

// Generate a valid ReScript identifier from a CSS class name
let toReScriptIdentifier = className => {
  let identifier = className->toCamelCase

  // Handle names starting with numbers
  let identifier = if %re("/^[0-9]/")->RegExp.test(identifier) {
    "_" ++ identifier
  } else {
    identifier
  }

  // Escape ReScript keywords
  if rescriptKeywords->Set.has(identifier) {
    identifier ++ "_"
  } else {
    identifier
  }
}

// Generate ReScript bindings for CSS module
let generateReScriptBindings = (cssFilePath, classNames) => {
  let fileName = cssFilePath->Node.Path.basename

  let bindings = classNames->Array.map(className => {
    let identifier = className->toReScriptIdentifier
    `  @module("./${fileName}") @val external ${identifier}: string = "${className}"`
  })

  `// Generated from ${fileName}
// Do not edit manually

${bindings->Array.join("\n")}
`
}

// Generate output filename from CSS module path
// Card.module.scss -> Card_module.res
let getOutputFileName = cssFilePath => {
  let baseName = cssFilePath->Node.Path.basename
  baseName
  ->String.replaceRegExp(%re("/\./g"), "_")
  ->String.replaceRegExp(%re("/_css$|_scss$/"), "")
  ++ ".res"
}

// Process a single CSS module file
let processFile = (cssFilePath, outputDir) => {
  let content = Node.Fs.readFileSync(cssFilePath, "utf-8")
  let classNames = content->extractClassNames

  if classNames->Array.length == 0 {
    Console.log(`⚠️  No classes found in ${cssFilePath}`)
    None
  } else {
    let bindings = generateReScriptBindings(cssFilePath, classNames)
    let outputFileName = cssFilePath->getOutputFileName
    let outputPath = Node.Path.join(
      outputDir->Option.getOr(cssFilePath->Node.Path.dirname),
      outputFileName,
    )

    Node.Fs.writeFileSync(outputPath, bindings)
    Console.log(`✅ Generated ${outputPath} (${classNames->Array.length->Int.toString} classes)`)

    (outputPath, classNames)->Some
  }
}

// Find all CSS module files recursively
let rec findModules = dir => {
  let entries = Node.Fs.readdirSync(dir, {"withFileTypes": true})

  entries->Array.flatMap(entry => {
    let fullPath = Node.Path.join(dir, entry["name"])
    if entry["isDirectory"]() {
      findModules(fullPath)
    } else if %re("/\.module\.(css|scss)$/")->RegExp.test(entry["name"]) {
      [fullPath]
    } else {
      []
    }
  })
}

// Print usage
let printUsage = () => {
  Console.log(`
CSS Modules to ReScript Converter

Usage:
  node CssToRescript.res.mjs <file.module.css|scss> [--output-dir <dir>]
  node CssToRescript.res.mjs <directory> [--output-dir <dir>]

Examples:
  node CssToRescript.res.mjs src/Card.module.scss
  node CssToRescript.res.mjs src/components --output-dir src/bindings
`)
}

// CLI entry point
let main = () => {
  let args = Node.Process.argv->Array.sliceToEnd(~start=2)

  if args->Array.length == 0 {
    printUsage()
    Node.Process.exit(1)
  }

  let inputPath = args->Array.getUnsafe(0)
  let outputDirIndex = args->Array.findIndex(arg => arg == "--output-dir")
  let outputDir = if outputDirIndex != -1 {
    args->Array.get(outputDirIndex + 1)
  } else {
    None
  }

  let stat = Node.Fs.statSync(inputPath)

  if stat["isFile"]() {
    processFile(inputPath, outputDir)->ignore
  } else if stat["isDirectory"]() {
    let moduleFiles = findModules(inputPath)
    Console.log(`Found ${moduleFiles->Array.length->Int.toString} CSS module files\n`)

    moduleFiles->Array.forEach(file => {
      processFile(file, outputDir)->ignore
    })
  }
}

main()
