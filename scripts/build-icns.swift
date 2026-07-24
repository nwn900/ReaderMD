import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: build-icns.swift ICONSET_DIR OUTPUT.icns\n", stderr)
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let representations = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndian(_ value: Int) -> Data {
    var integer = UInt32(value).bigEndian
    return withUnsafeBytes(of: &integer) { Data($0) }
}

do {
    var chunks = Data()

    for (type, filename) in representations {
        let png = try Data(contentsOf: iconsetURL.appendingPathComponent(filename))
        guard let typeData = type.data(using: .ascii), typeData.count == 4 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        chunks.append(typeData)
        chunks.append(bigEndian(png.count + 8))
        chunks.append(png)
    }

    var file = Data("icns".utf8)
    file.append(bigEndian(chunks.count + 8))
    file.append(chunks)
    try file.write(to: outputURL, options: .atomic)
} catch {
    fputs("Could not build ICNS: \(error.localizedDescription)\n", stderr)
    exit(1)
}
