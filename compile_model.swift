#!/usr/bin/env swift

import Foundation
import CoreML

// ==========================================
// CONFIGURATION
// Replace this with the path to your model
// ==========================================
let mlpackagePathString = "/path/to/your/model.mlpackage"

// 1. Enforce root privileges required for system compilation tasks
guard getuid() == 0 else {
    print("❌ Error: This script must be run with 'sudo'.")
    exit(1)
}

// 2. Resolve the original non-root user profile to target their Documents directory
guard let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"], !sudoUser.isEmpty else {
    print("❌ Error: Unable to determine the original user profile environment.")
    exit(1)
}

let srcURL = URL(fileURLWithPath: mlpackagePathString)
let modelName = srcURL.deletingPathExtension().lastPathComponent
let documentsDirectory = URL(fileURLWithPath: "/Users/\(sudoUser)/Documents")
let outputModelcURL = documentsDirectory.appendingPathComponent("\(modelName).mlmodelc")

print("🚀 Starting Terminal-Native CoreML Pipeline...")

// --- STEP 1: Compile the .mlpackage ---
print("📦 Compiling \(srcURL.lastPathComponent) via xcrun coremlcompiler...")
guard FileManager.default.fileExists(atPath: srcURL.path) else {
    print("❌ Error: Source model package not found at \(srcURL.path)")
    exit(1)
}

let compileProcess = Process()
compileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
compileProcess.arguments = ["coremlcompiler", "compile", srcURL.path, documentsDirectory.path]

do {
    try compileProcess.run()
    compileProcess.waitUntilExit()
    if compileProcess.terminationStatus != 0 {
        print("❌ Error: Compiler engine failure (Exit code: \(compileProcess.terminationStatus))")
        exit(1)
    }
} catch {
    print("❌ Error: Failed to execute system compiler process: \(error.localizedDescription)")
    exit(1)
}

// --- STEP 2: Restore Standard Permissions ---
print("🔑 Updating container security permissions...")
let chownProcess = Process()
chownProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/chown")
chownProcess.arguments = ["-R", sudoUser, outputModelcURL.path]
try? chownProcess.run()
chownProcess.waitUntilExit()

print("✅ Target successfully saved to: \(outputModelcURL.path)")

// --- STEP 3: Swift Runtime Evaluation ---
print("\n🧠 Instantiating CoreML Evaluation Interface...")
let config = MLModelConfiguration()
config.computeUnits = .all // Leverages CPU, GPU, and Apple Neural Engine (ANE)

do {
    let model = try MLModel(contentsOf: outputModelcURL, configuration: config)
    print("✅ Model runtime engine validation: SUCCESS.")
    
    print("\n--- Model Feature Blueprint ---")
    print("Inputs:")
    for input in model.modelDescription.inputDescriptionsByName {
        print("  🎛️  \(input.key) (\(input.value.type.rawValue))")
    }
    print("Outputs:")
    for output in model.modelDescription.outputDescriptionsByName {
        print("  📊 \(output.key) (\(output.value.type.rawValue))")
    }
    print("\n🎉 Evaluation complete. Ready for production.")
} catch {
    print("❌ Error: Structural runtime evaluation failure: \(error.localizedDescription)")
    exit(1)
}
