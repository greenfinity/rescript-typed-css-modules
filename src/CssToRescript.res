// CSS Modules to ReScript converter
// Extracts class names from .module.css/.module.scss and .global.css/.global.scss files
// and generates ReScript bindings

module Meow = {
  type flag = {
    @as("type") type_: string,
    shortFlag?: string,
    default?: bool,
  }

  type flags = {"watch": flag, "outputDir": flag, "skipInitial": flag}

  type importMeta

  type options = {
    importMeta: importMeta,
    flags: flags,
    allowUnknownFlags?: bool,
  }

  type result = {
    input: array<string>,
    flags: {"watch": bool, "outputDir": option<string>, "skipInitial": bool},
    showHelp: unit => unit,
  }

  @module("meow") external make: (string, options) => result = "default"

  @val external importMeta: importMeta = "import.meta"
}

// Chokidar bindings for file watching
module Chokidar = {
  type watcher

  @module("chokidar")
  external watch: (array<string>, {"ignored": string => bool, "persistent": bool}) => watcher =
    "watch"

  @send external on: (watcher, string, string => unit) => watcher = "on"
  @send external onReady: (watcher, @as("ready") _, unit => unit) => watcher = "on"
  @send external close: watcher => promise<unit> = "close"
}

module PostCss = {
  type plugin
  type syntax
  type t
  type processOptions = {from: string, syntax?: syntax}

  @module("postcss")
  external make: array<plugin> => t = "default"

  @send external process: (t, string, processOptions) => promise<t> = "process"
}

module PostCssScss = {
  @module("postcss-scss")
  external syntax: PostCss.syntax = "default"
}

module PostCssImport = {
  @module("postcss-import")
  external make: unit => PostCss.plugin = "default"
}

module PostCssModules = {
  type pluginOptions = {getJSON: (string, Dict.t<string>) => unit, exportGlobals?: bool}

  @module("postcss-modules")
  external make: pluginOptions => PostCss.plugin = "default"
}

// Extract class names from CSS/SCSS content
// Uses postcss-import to resolve @imported files
// ~from is required for the source map generation
let extractClassNames = async (cssContent, ~from) =>
  (
    await Promise.make((resolve, _) => {
      let classNames = ref([])
      PostCss.make([
        PostCssImport.make(),
        PostCssModules.make({
          getJSON: (_, json) => {classNames := json->Dict.keysToArray},
          exportGlobals: true,
        }),
      ])
      ->PostCss.process(cssContent, {from, syntax: PostCssScss.syntax})
      ->Promise.thenResolve(_ => classNames.contents->resolve)
      ->ignore
    })
  )->Array.toSorted(String.compare)

type importType = Module | Global

// Generate ReScript binding's for CSS module
let generateReScriptBindings = (baseName, importType, classNames) => {
  let recordFields = classNames->Array.map(className => `  "${className}": string`)
  let prelude = `// Generated from ${baseName}
// Do not edit manually

type t = {
${recordFields->Array.join(",\n")}
}
`
  switch importType {
  | Module =>
    // CSS Module import will get access to the object mapping returned
    // by the import. Hashing will happen automatically.
    prelude +
    `@module("./${baseName}") external css: t = "default"

// Access class names from the fields of the css object.
// For scoped classses, the hashed class name is returned.
// For :global() classes, the class name is returned as-is: no scoping.
// Classes from @import are also available.

@module("./${baseName}") external _imported: t = "default"
@new external proxy: ('a, 'b) => 'c = "Proxy"
%%private(
  external toDict: t => dict<string> = "%identity"
  let withProxy = (obj: t): t =>
    proxy(
      obj,
      {
        // "get": (_b, _c): string => %raw("_b[_c] || _c"),
        "get": (base, className) =>
          switch base->toDict->Dict.get(className) {
          | Some(className) => className
          | None => className
          },
      },
    )
)
let css = withProxy(css)


`
  | Global =>
    // Global css will return the css class name as-is: no scoping.
    // Import is not done.
    prelude + `
// Access class names from the fields of the css object.
// Import is not done, the css has to be manually imported
// from the top of the component hierarchy.
// For all classes, the class name is returned as-is: no scoping.
// Classes from @import are also available.

@new external proxy: ('a, 'b) => 'c = "Proxy"
type empty = {}
%%private(
  let withProxy = (obj: empty): t =>
    proxy(
      obj,
      {
        "get": (_: empty, className: string): string => className,
      },
    )
)
let css = withProxy({})
`
  }
}

// Determines the base name and import type of a CSS file
// Card.module.scss -> ("Card", Module)
// Card.global.scss -> ("Card", Global)
let getBaseNameAndImportType = cssFilePath => {
  let baseName = cssFilePath->NodeJs.Path.basename
  (
    baseName,
    if /\.module\.(css|scss)$/->RegExp.test(baseName) {
      Module
    } else {
      Global
    },
  )
}

// Generate output filename from CSS module/global path
// ("Card", Module) -> "Card_CssModule.res"
// ("Card", Global) -> "Card_CssGlobal.res"
let getOutputFileName = (baseName, importType) => {
  switch importType {
  | Module => baseName->String.replaceRegExp(/\.module\.(css|scss)$/, "_CssModule") ++ ".res"
  | Global => baseName->String.replaceRegExp(/\.global\.(css|scss)$/, "_CssGlobal") ++ ".res"
  }
}

// Process a single CSS module file
let processFile = async (cssFilePath, outputDir) => {
  let content = NodeJs.Fs.readFileSync(cssFilePath)->NodeJs.Buffer.toString
  Console.log(`Processing file: ${cssFilePath}`)
  let classNames = await extractClassNames(content, ~from=cssFilePath)

  if classNames->Array.length == 0 {
    Console.log(`⚠️  No classes found in ${cssFilePath}`)
    None
  } else {
    let (baseName, importType) = cssFilePath->getBaseNameAndImportType
    let outputFileName = getOutputFileName(baseName, importType)
    let bindings = generateReScriptBindings(baseName, importType, classNames)
    let outputPath = NodeJs.Path.join2(
      outputDir->Option.getOr(cssFilePath->NodeJs.Path.dirname),
      outputFileName,
    )

    NodeJs.Fs.writeFileSync(outputPath, NodeJs.Buffer.fromString(bindings))
    Console.log(`✅ Generated ${outputPath} (${classNames->Array.length->Int.toString} classes)`)

    (outputPath, classNames)->Some
  }
}

// Find all CSS module and global files recursively
let rec findCssFiles = dir => {
  let entries = NodeJs.Fs.readdirSync(dir)

  entries->Array.flatMap(entry => {
    let fullPath = NodeJs.Path.join2(dir, entry)
    let stat = NodeJs.Fs.lstatSync(#String(fullPath))
    if stat->NodeJs.Fs.Stats.isDirectory {
      findCssFiles(fullPath)
    } else if /\.(module|global)\.(css|scss)$/->RegExp.test(entry) {
      [fullPath]
    } else {
      []
    }
  })
}

// Watch directories for CSS module and global file changes
let watchDirectories = async (dirs, outputDir, ~skipInitial) => {
  Console.log(
    `👀 Watching ${dirs
      ->Array.length
      ->Int.toString} directories for CSS module/global changes...`,
  )
  dirs->Array.forEach(dir => Console.log(`   ${dir}`))
  if skipInitial {
    Console.log(`Skipping initial compilation.`)
  }
  Console.log(`Press Ctrl+C to stop.\n`)

  // Set up chokidar watcher for CSS module and global files
  let isIgnored = path => {
    // Ignore dotfiles and non-CSS module/global files
    let isDotfile = /(^|[\/\\])\./->RegExp.test(path)
    let isCssFile = /\.(module|global)\.(css|scss)$/->RegExp.test(path)
    let isDir =
      NodeJs.Fs.existsSync(path) && NodeJs.Fs.lstatSync(#String(path))->NodeJs.Fs.Stats.isDirectory
    isDotfile || (!isCssFile && !isDir)
  }

  let ready = ref(false)

  Chokidar.watch(dirs, {"ignored": isIgnored, "persistent": true})
  ->Chokidar.onReady(() => {
    ready := true
    Console.log(`Ready for changes.`)
  })
  ->Chokidar.on("change", path => {
    Console.log(`\nChanged: ${path}`)
    processFile(path, outputDir)->ignore
  })
  ->Chokidar.on("add", path => {
    // Skip initial files if skipInitial is set
    if skipInitial && !ready.contents {
      ()
    } else {
      Console.log(`\nAdded: ${path}`)
      processFile(path, outputDir)->ignore
    }
  })
  ->Chokidar.on("unlink", path => {
    Console.log(`\n🗑️  Deleted: ${path}`)
  })
  ->ignore
}

let helpText = `
  Usage
    $ css-to-rescript <file.module.css|scss|global.css|scss...>
    $ css-to-rescript <directory...>

  Generates ReScript bindings from CSS module and global files:
    *.module.css|scss -> *_CssModule.res
    *.global.css|scss -> *_CssGlobal.res

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
`

let main = async () => {
  let cli = Meow.make(
    helpText,
    {
      importMeta: Meow.importMeta,
      flags: {
        "watch": {Meow.type_: "boolean", shortFlag: "w", default: false},
        "outputDir": {Meow.type_: "string", shortFlag: "o"},
        "skipInitial": {Meow.type_: "boolean", shortFlag: "s", default: false},
      },
      allowUnknownFlags: false,
    },
  )

  let inputPaths = cli.input

  if inputPaths->Array.length == 0 {
    cli.showHelp()
    NodeJs.Process.process->NodeJs.Process.exitWithCode(1)
  }

  let outputDir = cli.flags["outputDir"]
  let watchMode = cli.flags["watch"]
  let skipInitial = cli.flags["skipInitial"]

  // Classify inputs as files or directories
  let (files, dirs) = inputPaths->Array.reduce(([], []), ((files, dirs), path) => {
    let stat = NodeJs.Fs.lstatSync(#String(path))
    if stat->NodeJs.Fs.Stats.isFile {
      (files->Array.concat([path]), dirs)
    } else if stat->NodeJs.Fs.Stats.isDirectory {
      (files, dirs->Array.concat([path]))
    } else {
      (files, dirs)
    }
  })

  // Validation: watch mode only supports directories
  if watchMode && files->Array.length > 0 {
    Console.error(`Error: Watch mode only supports directories, not files.`)
    NodeJs.Process.process->NodeJs.Process.exitWithCode(1)
  }

  // Validation: output-dir only supports multiple files OR single directory
  if (
    outputDir->Option.isSome &&
      (dirs->Array.length > 1 || (files->Array.length > 0 && dirs->Array.length > 0))
  ) {
    Console.error(`Error: --output-dir only supports multiple files or a single directory, not mixed inputs or multiple directories.`)
    NodeJs.Process.process->NodeJs.Process.exitWithCode(1)
  }

  // Process files
  if files->Array.length > 0 {
    await files->Array.reduce(Promise.resolve(), async (acc, file) => {
      await acc
      (await processFile(file, outputDir))->ignore
    })
  }

  // Process directories
  if dirs->Array.length > 0 {
    if watchMode {
      await watchDirectories(dirs, outputDir, ~skipInitial)
    } else {
      let moduleFiles = dirs->Array.flatMap(findCssFiles)
      Console.log(`Found ${moduleFiles->Array.length->Int.toString} CSS module files\n`)

      await moduleFiles->Array.reduce(Promise.resolve(), async (acc, file) => {
        await acc
        (await processFile(file, outputDir))->ignore
      })
    }
  }
}

main()->ignore
