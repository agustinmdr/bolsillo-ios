#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/bolsillo-checks.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -module-cache-path "$test_dir/modules" \
  Core/Models/Finance.swift Core/Domain/Operations.swift \
  Core/Services/Export/ExcelReport.swift Core/Services/Wallet/WalletCapture.swift \
  Core/Services/Storage/LedgerStorage.swift Tests/main.swift Tests/OperationsChecks.swift \
  -o "$test_dir/finance"
"$test_dir/finance"
xcrun swiftc -module-cache-path "$test_dir/modules" \
  Core/Models/Finance.swift Core/Domain/Operations.swift \
  Core/Services/Storage/LedgerStorage.swift Core/Services/Cloud/CloudSync.swift \
  Tests/CloudSync/Checks.swift -o "$test_dir/cloud"
"$test_dir/cloud"
