#!/bin/bash
#
# PR#62 Block Boundary Fix Verification Script
#
# This script verifies that PR#62 fixed the block boundary bug by:
# 1. Testing the code at commit bba57c1 (before PR#62)
# 2. Testing the current code (after PR#62)
# 3. Comparing results to show the fix works
#
# Usage: ./verify_pr62_fix.sh <path_to_metaldio_repo>
#

# Note: Do NOT use 'set -e' because we expect the BEFORE test to fail

# Check if repo path provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_metaldio_repo>"
    echo ""
    echo "Example: $0 ~/metaldio"
    exit 1
fi

METALDIO_REPO="$1"

# Verify repo exists
if [ ! -d "${METALDIO_REPO}" ]; then
    echo "ERROR: Directory not found: ${METALDIO_REPO}"
    exit 1
fi

if [ ! -d "${METALDIO_REPO}/.git" ]; then
    echo "ERROR: Not a git repository: ${METALDIO_REPO}"
    exit 1
fi

# Configuration
COMMIT_BEFORE_FIX="bba57c1"  # Last commit before PR#62
WORK_DIR="/tmp/pr62_verification_$$"
TESTFILE="${WORK_DIR}/large_test.txt"
EXPECTED_LINES=100

echo "=========================================="
echo "PR#62 Block Boundary Fix Verification"
echo "=========================================="
echo ""
echo "Repository: ${METALDIO_REPO}"
echo "Work directory: ${WORK_DIR}"
echo ""

# Save current state
cd "${METALDIO_REPO}"
ORIGINAL_COMMIT=$(git rev-parse HEAD)
ORIGINAL_BRANCH=$(git branch --show-current)

echo "Current commit: ${ORIGINAL_COMMIT}"
echo "Current branch: ${ORIGINAL_BRANCH}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Restore original commit
    cd "${METALDIO_REPO}"
    echo "Restoring original commit..."
    if [ -n "${ORIGINAL_BRANCH}" ]; then
        git checkout "${ORIGINAL_BRANCH}" 2>/dev/null || git checkout "${ORIGINAL_COMMIT}"
    else
        git checkout "${ORIGINAL_COMMIT}"
    fi

    # Clean work directory
    rm -rf "${WORK_DIR}"

    echo "Cleanup complete"
}

trap cleanup EXIT

# Create work directory
mkdir -p "${WORK_DIR}"

# Function to create test file
create_test_file() {
    echo "Creating test file with ${EXPECTED_LINES} lines..."

    local tempps="$(hlq).METALDIO.TEMPPS"
    echo "  Temporary PS dataset: ${tempps}"
    echo "  Target USS file: ${TESTFILE}"
    echo ""

    drm -f "${tempps}" 2>/dev/null || true

    # Allocate PS dataset for 100 records of 1024 bytes each
    # 100 records × 1,024 bytes = 102,400 bytes
    # 1 track (3390) = 56,664 bytes
    # 102,400 ÷ 56,664 = 1.8 tracks, round up to 2 tracks
    # Secondary allocation: 1 track
    echo "  Allocating PS dataset (2 tracks for 100 records)..."
    if ! dtouch -tSEQ -l1024 -rFB -s2TRK -e1TRK "${tempps}"; then
        echo "ERROR: Failed to allocate temporary PS dataset"
        exit 1
    fi

    # Generate data with IEBDG
    echo "  Generating test data with IEBDG..."
    if ! mvscmd --pgm=IEBDG --out="${tempps},old" --sysprint=stdout --sysin=stdin > /dev/null 2>&1 << EOF
  DSD OUTPUT=(OUT)
  FD  NAME=FIELD1,LENGTH=1024,FORMAT=AL,ACTION=RP
  CREATE QUANTITY=100,NAME=FIELD1
  END
EOF
    then
        echo "ERROR: Failed to generate test data with IEBDG"
        exit 1
    fi

    # Copy to USS file
    echo "  Copying PS dataset to USS file..."
    if ! cp "//'${tempps}'" "${TESTFILE}"; then
        echo "ERROR: Failed to copy PS dataset to USS file"
        exit 1
    fi

    # Cleanup temp dataset
    drm -f "${tempps}" 2>/dev/null || true

    local actual_lines=$(wc -l < "${TESTFILE}")
    echo ""
    echo "Test file created successfully:"
    echo "  File: ${TESTFILE}"
    echo "  Lines: ${actual_lines}"
    echo ""
}

# Function to build and test a version
test_version() {
    local version_name="$1"
    local commit="$2"

    echo "=========================================="
    echo "Testing: ${version_name}"
    echo "=========================================="

    cd "${METALDIO_REPO}"

    # Checkout specific commit
    echo "Checking out commit ${commit}..."
    if ! git checkout "${commit}" > /dev/null 2>&1; then
        echo "ERROR: Failed to checkout commit ${commit}"
        return 1
    fi

    # Build
    echo "Building..."
    export ASMDIOROOT="${METALDIO_REPO}"
    . ./setenv
    if ! gmake clean > /dev/null 2>&1; then
        echo "WARNING: gmake clean failed, continuing..."
    fi
    if ! gmake > /dev/null 2>&1; then
        echo "ERROR: Build failed"
        return 1
    fi

    # Allocate test dataset
    local testds="$(hlq).METALDIO.PR62.${version_name}"
    echo "Allocating test dataset..."
    echo "  Dataset: ${testds}"
    echo "  LRECL=1024, BLKSIZE=1024, RECFM=FB"
    drm -f "${testds}" 2>/dev/null || true
    # if ! dtouch -tPDSE -l1024 -rFB -s2TRK -e1TRK "${testds}"; then
    if ! dtouch -tPDSE -l1024 -rFB "${testds}"; then
        echo "ERROR: Failed to allocate test dataset"
        return 1
    fi

    # Copy test file to data directory
    local test_data_dir="${METALDIO_REPO}/data"
    local test_data_file="${test_data_dir}/large.txt"
    echo "Preparing test file..."
    echo "  Source: ${TESTFILE}"
    echo "  Target: ${test_data_file}"
    mkdir -p "${test_data_dir}"
    if ! cp "${TESTFILE}" "${test_data_file}"; then
        echo "ERROR: Failed to copy test file"
        drm -f "${testds}" 2>/dev/null || true
        return 1
    fi

    # Copy file to dataset
    echo "Copying file to dataset using f2m..."
    echo "  Command: sample/bin/f2m -i data ${testds} large.txt"
    if ! sample/bin/f2m -i data "${testds}" large.txt; then
        echo "ERROR: f2m failed"
        drm -f "${testds}" 2>/dev/null || true
        return 1
    fi

    # Count lines in member
    echo "Verifying member..."
    echo "  Member: ${testds}(LARGE)"
    local actual_lines=$(dcat "${testds}(LARGE)" | awk NF | wc -l)
    local lost_lines=$((EXPECTED_LINES - actual_lines))

    echo ""
    echo "RESULTS:"
    echo "  Expected lines: ${EXPECTED_LINES}"
    echo "  Actual lines:   ${actual_lines}"

    # Cleanup test dataset
    # drm -f "${testds}" 2>/dev/null || true

    if [ "${actual_lines}" -eq "${EXPECTED_LINES}" ]; then
        echo "  Status:         PASS - All lines preserved"
        echo ""
        return 0
    else
        echo "  Lost lines:     ${lost_lines}"
        echo "  Status:         FAIL - Records lost at block boundaries"
        echo ""
        return 1
    fi
}

# Main execution
echo "Step 1: Creating test file..."
create_test_file

echo "Step 2: Testing BEFORE PR#62 fix (commit ${COMMIT_BEFORE_FIX})..."
test_version "BEFORE" "${COMMIT_BEFORE_FIX}"
BEFORE_RESULT=$?

echo "Step 3: Testing AFTER PR#62 fix (current code)..."
test_version "AFTER" "${ORIGINAL_COMMIT}"
AFTER_RESULT=$?

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

if [ ${BEFORE_RESULT} -ne 0 ] && [ ${AFTER_RESULT} -eq 0 ]; then
    echo "SUCCESS: PR#62 fix verified!"
    echo ""
    echo "  - BEFORE PR#62 (commit ${COMMIT_BEFORE_FIX}):"
    echo "    Records were lost at block boundaries"
    echo ""
    echo "  - AFTER PR#62 (commit ${ORIGINAL_COMMIT}):"
    echo "    All records preserved correctly"
    echo ""
    echo "The fix in services/src/bpamio.c:write_record() successfully"
    echo "prevents record loss when a record doesn't fit in the current block."
    echo ""
    exit 0
elif [ ${BEFORE_RESULT} -eq 0 ] && [ ${AFTER_RESULT} -eq 0 ]; then
    echo "WARNING: Both tests passed"
    echo ""
    echo "The bug may not exist in commit ${COMMIT_BEFORE_FIX}."
    echo "This could mean:"
    echo "  - The commit hash is incorrect"
    echo "  - The test conditions don't trigger the bug"
    echo ""
    exit 1
elif [ ${BEFORE_RESULT} -ne 0 ] && [ ${AFTER_RESULT} -ne 0 ]; then
    echo "FAILURE: Both tests failed"
    echo ""
    echo "PR#62 fix may not be working correctly."
    echo "Both versions are losing records at block boundaries."
    echo ""
    exit 1
else
    echo "FAILURE: Unexpected test results"
    echo ""
    echo "BEFORE result: ${BEFORE_RESULT}"
    echo "AFTER result: ${AFTER_RESULT}"
    echo ""
    exit 1
fi

# Made with Bob
