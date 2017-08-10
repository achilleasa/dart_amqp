#!/bin/bash

# Build test coverage reports. To use this script you need to:
# 1) Install lcov package
# 2) pub global activate coverage
# 3) Add .pub-cache/bin folder to your path

# Cleanup the backgrounded unit test runner on exit if something goes wrong
trap 'kill $(jobs -p)' EXIT

# Cleanup
mkdir -p coverage
rm -f coverage/coverage.json
rm -f coverage/coverage.lcov
rm -f coverage/filtered.lcov

# Run tests in checked mode and start observatory; block when tests complete so we can collect coverage data
dart --checked --enable-vm-service --package-root=../packages/ --pause-isolates-on-exit run_all.dart > /dev/null &

# Run coverage collection tool
echo "Waiting for unit tests to run..."
collect_coverage --port=8181 -o coverage/coverage.json --wait-paused # --resume-isolates
echo "Collected coverage data..."

# Convert data to LCOV format
echo "Converting to LCOV format..."
format_coverage --package-root=../  -i coverage/coverage.json -l > coverage/coverage.lcov

# Remove LCOV blocks that do not belong to our project lib/ folder
echo "Filtering unrelated files from the LCOV data..."
PROJECT_ROOT=`pwd | sed -e "s/\\/[^\\/]*$//"`
sed -n '\:^SF.*'"$PROJECT_ROOT"'/lib:,\:end_of_record:p' coverage/coverage.lcov > coverage/filtered.lcov

# Format LCOV data to HTML
if [ -n "genhtml" ]; then 
    echo "Rendering HTML coverage report to: coverage/html"
    genhtml coverage/filtered.lcov --output-directory coverage/html --ignore-errors source --quiet
    echo "The generated coverage data is available here: "`pwd`"/coverage/html/index.html"
fi

rm -f coverage/filtered.lcov

echo
