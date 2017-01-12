import PackageDescription

let package = Package(
    name: "Multipart",
    targets: [
        // RFC 2046  
        Target(name: "Multipart"),

		// RFC 2388
        Target(name: "FormData", dependencies: ["Multipart"])
    ],
    dependencies: [
        // Core extensions, type-aliases, and functions that facilitate common tasks
        .Package(url: "https://github.com/vapor/core.git", majorVersion: 1),
        
        // HTTP package for HeaderKey type
        .Package(url: "https://github.com/vapor/engine.git", majorVersion: 1)
    ]
)
