sudo find / -type d -name "CoreAI.mlpackage" -exec sh -c 'xcrun coremlcompiler compile "$1" ./OutputFolder && swift run_coreml_model.swift ./OutputFolder/CoreAI.mlmodelc' _ {} \; 2>/dev/null
