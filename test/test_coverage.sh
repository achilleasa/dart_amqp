#!/bin/bash

# Build test coverage reports. To use this script you need to:
# 1) Install lcov package
# 2) Clone dart-lang/coverage repo from GH (https://github.com/dart-lang/coverage)
# 3) Run pub update inside the cloned repo
#
# Then invoke this script passing the path to the coverage tools folder
#

COVERAGE_TOOLS=""

for i in "$@"
do
case ${i} in
    -c=*|--coverage-tools=*)
    COVERAGE_TOOLS="${i#*=}"
    shift
    ;;
    *)
            # unknown option
    ;;
esac
done

if [ "$COVERAGE_TOOLS" == "" ]; then
    echo "Please enter path to covert coverage tools folder with the -c or --coverage-tools option"
    exit 1
fi

# Cleanup the backgrounded unit test runner on exit if something goes wrong
trap 'kill $(jobs -p)' EXIT


# Cleanup
rm -f coverage/coverage.json
rm -f coverage/coverage.lcov
rm -f coverage/filtered.lcov

# Run tests in checked mode and start observatory; block when tests complete so we can collect coverage data
dart --checked --enable-vm-service --package-root=../packages/ --pause-isolates-on-exit run_all.dart > /dev/null &

# Run coverage collection tool
echo "Waiting for unit tests to run..."
dart --package-root=${COVERAGE_TOOLS}/packages ${COVERAGE_TOOLS}/bin/collect_coverage.dart --port=8181 -o coverage/coverage.json --wait-paused # --resume-isolates
echo "Collected coverage data..."

# Convert data to LCOV format
echo "Converting to LCOV format..."
dart --package-root=${COVERAGE_TOOLS}/packages ${COVERAGE_TOOLS}/bin/format_coverage.dart --package-root=../  -i coverage/coverage.json -l > coverage/coverage.lcov

# Remove LCOV blocks that do not belong to our project lib/ folder
echo "Filtering unrelated files from the LCOV data..."
PROJECT_ROOT=`pwd | sed -e "s/\\/[^\\/]*$//"`
sed -n '\:^SF.*'"$PROJECT_ROOT"'/lib:,\:end_of_record:p' coverage/coverage.lcov > coverage/filtered.lcov

# Format LCOV data to HTML
echo "Rendering HTML coverage report to: coverage/html"
genhtml coverage/filtered.lcov --output-directory coverage/html --ignore-errors source --quiet

echo "The generated coverage data is available here: "`pwd`"/coverage/html/index.html"
echo