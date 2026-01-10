# Knitting Helper - Copilot Instructions

# Project (no workspace)
## running a build:
- xcodebuild -project "knitting helper.xcodeproj" -scheme "knitting helper" -configuration Debug -sdk iphonesimulator build | tee xcodebuild.log

Notes:
- ALWAYS run a build and confirm no errors are present before declaring that code is ready.
  - Do not ask for permission to run the build, just do it and iterate on any errors until it is fixed
- Use `-sdk iphonesimulator` to avoid code-signing issues.
- Inspect `xcodebuild.log` for errors; non-zero exit indicates failure.