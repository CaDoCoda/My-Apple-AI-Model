#!/bin/zsh

# ==========================================
# CONFIGURATION
# Replace this with the path to your model
# ==========================================
local mlpackage_path="/path/to/your/model.mlpackage"

# 1. Ensure the script is run with sudo
if (( EUID != 0 )); then
    print -u2 "❌ Error: This script must be run with sudo."
    exit 1
fi

# 2. Get the non-root user details using Zsh environment variables
local sudo_user=$SUDO_USER
if [[ -z $sudo_user ]]; then
    print -u2 "❌ Error: Could not verify original non-root user."
    exit 1
fi

local documents_dir="/Users/$sudo_user/Documents"
local model_name=${mlpackage_path:t:r} # Zsh modifier: :t gets basename, :r removes extension
local output_modelc="$documents_dir/${model_name}.mlmodelc"

print "=== Step 1: Compiling .mlpackage ==="
if [[ ! -d $mlpackage_path ]]; then
    print -u2 "❌ Error: Source .mlpackage not found at $mlpackage_path"
    exit 1
fi

# Compile using the Xcode Command Line Tools compiler
xcrun coremlcompiler compile "$mlpackage_path" "$documents_dir"

if (( ? != 0 )); then
    print -u2 "❌ Error: Compilation failed."
    exit 1
fi

# Adjust ownership of the compiled output directory back to the standard user
chown -R "$sudo_user" "$output_modelc"
print "✅ Compiled model saved to: $output_modelc"

print "\n=== Step 2: Evaluating Model with Swift Interpreter ==="

# Feed the Swift code directly into the interpreter via a Heredoc
# We run this as the standard user to drop root privileges for the execution phase
sudo -u "$sudo_user" swift - "$output_modelc" << 'EOF'
import Foundation
import CoreML

// Fetch the compiled model path from the arguments passed by the shell
let args = CommandLine.arguments
guard args.count > 1 else {
    print("❌ Swift Error: Missing model path argument.")
    exit(1)
}

let modelPath = args[1]
let modelURL = URL(fileURLWithPath: modelPath)

print("Loading model metadata into memory...")

let config = MLModelConfiguration()
config.computeUnits = .all // Utilizes CPU, GPU, and Neural Engine

do {
    let model = try MLModel(contentsOf: modelURL, configuration: config)
    print("✅ Success: Model binary loaded completely.")
    
    print("\n--- Model Feature Evaluation ---")
    print("Inputs:")
    for input in model.modelDescription.inputDescriptionsByName {
        print("  • \(input.key): \(input.value.type.rawValue)")
    }
    
    print("Outputs:")
    for output in model.modelDescription.outputDescriptionsByName {
        print("  • \(output.key): \(output.value.type.rawValue)")
    }
    
} catch {
    print("❌ Swift Error: Failed to evaluate or parse model binary.")
    print("Details: \(error.localizedDescription)")
    exit(1)
}
EOF
