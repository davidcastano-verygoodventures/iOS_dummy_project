#!/bin/bash
set -e

# --- CONFIGURATION ---
REPO_URL="https://github.com/davidcastano-verygoodventures/iOS_dummy_project.git"
PROJECT_DIR="pipeline-test"

# ==========================================
# 🚀 START SIMULATION
# ==========================================

# 1. Clean & Clone
if [ -d "$PROJECT_DIR" ]; then rm -rf "$PROJECT_DIR"; fi
echo "📥 Cloning repository..."
git clone "$REPO_URL" "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 2. Config Files
FORCE_GENERATE_CONFIG="${FORCE_GENERATE_CONFIG:-true}"

if [ "$FORCE_GENERATE_CONFIG" = "true" ]; then
    echo "⚠️  Generating temporary config files..."
    cat <<YAML > .swiftlint.yml
disabled_rules:
  - trailing_whitespace
included:
  - dummyProject
YAML

    mkdir -p fastlane
    cat <<RUBY > fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Run Pipeline"
  lane :pr_check do
    ENV['DEVELOPER_DIR'] = '$DEVELOPER_DIR'
    swiftlint(mode: :lint, config_file: ".swiftlint.yml")
    
    sonar(
       project_key: "PipelineTest",
       project_name: "PipelineTest",
       project_version: "1.0",
       sources_path: "dummyProject",
       sonar_runner_args: "-Dsonar.host.url=http://localhost:9000 -Dsonar.login=admin -Dsonar.password=admin123"
    )

    run_tests(
      project: "dummyProject/dummyProject.xcodeproj",
      scheme: "dummyProject",
      device: "iPhone 15",
      clean: true
    )
  end
end
RUBY
else
    echo "ℹ️  Using repository config files..."
fi

# 3. Dependencies
echo "💎 Checking Dependencies..."
# Ensure Bundler is available (should be from setup_mac.sh)
if ! command -v bundle &> /dev/null; then
    echo "❌ Bundler not found! Please run setup_mac.sh first."
    exit 1
fi

# [FIX] Add ostruct to Gemfile for newer Ruby versions (where it was removed from stdlib)
if [ -f "Gemfile" ]; then
    echo "   -> Adding 'ostruct' to Gemfile..."
    echo "gem \"ostruct\"" >> Gemfile
fi

echo "   -> Running Bundle Install..."
bundle config set --local path 'vendor/bundle'
bundle install --quiet

# 4. Execution
echo "🚀 Determining Execution Mode..."
if colima status &> /dev/null; then
    echo "✅ Docker is UP. Running via ACT..."
    act pull_request -P macos-15=-self-hosted --container-architecture linux/amd64
else
    echo "⚠️  Docker is DOWN. Falling back to DIRECT FASTLANE execution..."
    echo "---------------------------------------------------"
    bundle exec fastlane ios pr_check
fi

echo "✅ DONE!"
echo "📊 Dashboard: http://localhost:9000"
