#!/bin/bash
# Run this in your terminal (where Flutter is installed) to create platform folders, get deps, and run the app.
set -e
cd "$(dirname "$0")"

echo "Creating Flutter platform folders (if missing)..."
flutter create . --project-name leaky

echo "Getting dependencies..."
flutter pub get

echo "Running app..."
flutter run
