// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "UUID58",
  products: [
    .library(name: "UUID58", targets: ["UUID58"])
  ],
  targets: [
    .target(name: "UUID58"),
    .testTarget(
      name: "UUID58Tests",
      dependencies: ["UUID58"],
      resources: [
        // A copy of spec/vectors.json from nakanoasaservice/uuid58.
        // CI checks that it matches the upstream file.
        .copy("vectors.json")
      ]
    ),
  ]
)
