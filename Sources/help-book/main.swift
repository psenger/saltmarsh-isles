import Foundation
import SaltmarshGame

// Writes Apple's help book for the Mac from `Help.sections`, the same text the iPhone and iPad show.
// Run `make help` after changing that text: it also builds the search index.
guard CommandLine.arguments.count == 2 else {
    fputs("usage: help-book <path to SaltmarshIsles.help>\n", stderr)
    exit(1)
}
let book = URL(fileURLWithPath: CommandLine.arguments[1])
let contents = book.appending(path: "Contents")
let pages = contents.appending(path: "Resources/en.lproj")
try? FileManager.default.removeItem(at: book)
try FileManager.default.createDirectory(at: pages, withIntermediateDirectories: true)

func escaped(_ text: String) -> String {
    text.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;")
}

func page(title: String, description: String, isIndex: Bool = false, body: String) -> String {
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>\(escaped(title))</title>
    \(isIndex ? "<meta name=\"AppleTitle\" content=\"\(Help.bookTitle)\">\n" : "")<meta name="description" content="\(escaped(description))">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="help.css">
    </head>
    <body>
    \(body)
    </body>
    </html>

    """
}

var topics = ""
for section in Help.sections {
    let lines = section.lines.map { "<p>\(escaped($0))</p>" }.joined(separator: "\n")
    let body = """
    <nav><a href="index.html">\(Help.bookTitle)</a></nav>
    <main>
    <h1>\(escaped(section.title))</h1>
    \(lines)
    </main>
    """
    try page(title: section.title, description: section.lines[0], body: body)
        .write(to: pages.appending(path: "\(section.slug).html"), atomically: true, encoding: .utf8)
    topics += "<li><a href=\"\(section.slug).html\"><strong>\(escaped(section.title))</strong><span>\(escaped(section.lines[0]))</span></a></li>\n"
}
try page(title: Help.bookTitle, description: "How to play Saltmarsh Isles.", isIndex: true, body: """
    <main>
    <h1>\(Help.bookTitle)</h1>
    <ul class="topics">
    \(topics)</ul>
    </main>
    """).write(to: pages.appending(path: "index.html"), atomically: true, encoding: .utf8)

try """
    :root { color-scheme: light dark; --sea: #3f6472; --line: #d9d4c7; --muted: #5f6b70; }
    @media (prefers-color-scheme: dark) { :root { --sea: #8fbccb; --line: #3c4649; --muted: #a9b4b8; } }
    body { font: 15px/1.5 -apple-system, system-ui, sans-serif; margin: 0 auto; max-width: 640px; padding: 20px 24px 40px; }
    h1 { font-size: 24px; margin: 8px 0 16px; }
    nav a, a { color: var(--sea); text-decoration: none; }
    nav { font-size: 13px; }
    p { margin: 0 0 12px; }
    .topics { list-style: none; margin: 0; padding: 0; }
    .topics a { border-top: 1px solid var(--line); color: inherit; display: block; padding: 10px 0; }
    .topics strong { color: var(--sea); display: block; }
    .topics span { color: var(--muted); font-size: 13px; }
    """.write(to: pages.appending(path: "help.css"), atomically: true, encoding: .utf8)

let info: [String: Any] = [
    "CFBundleDevelopmentRegion": "en",
    "CFBundleIdentifier": Help.bookIdentifier,
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": "Saltmarsh Isles",
    "CFBundlePackageType": "BNDL",
    "CFBundleShortVersionString": "1",
    "CFBundleSignature": "hbwr",
    "CFBundleVersion": "1",
    "HPDBookAccessPath": "index.html",
    "HPDBookCSIndexPath": "SaltmarshIsles.cshelpindex",
    "HPDBookIndexPath": "SaltmarshIsles.helpindex",
    "HPDBookTitle": Help.bookTitle,
    "HPDBookType": "3",
]
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    .write(to: contents.appending(path: "Info.plist"))
print("wrote \(Help.sections.count) topics to \(pages.path)")
