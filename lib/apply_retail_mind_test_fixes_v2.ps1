param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

# Always resolve files from the project root, not from the caller's current folder.
$root = (Resolve-Path $ProjectRoot).Path
$saleFile = Join-Path $root 'lib\sale_service.dart'
$widgetFile = Join-Path $root 'test\widget_test.dart'

if (-not (Test-Path $saleFile)) {
    throw "Could not find lib\sale_service.dart under $root"
}

# --- sale_service.dart ---
$content = [System.IO.File]::ReadAllText($saleFile)

# Find the paymentStatusFor method by signature and replace its body using brace matching.
$signature = 'static String paymentStatusFor(double paidAmount, double grandTotal) {'
$start = $content.IndexOf($signature, [System.StringComparison]::Ordinal)
if ($start -lt 0) {
    throw "Could not find paymentStatusFor signature in $saleFile"
}

$bodyStart = $start + $signature.Length - 1  # index of opening {
$depth = 0
$end = -1
for ($i = $bodyStart; $i -lt $content.Length; $i++) {
    $ch = $content[$i]
    if ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') {
        $depth--
        if ($depth -eq 0) {
            $end = $i
            break
        }
    }
}
if ($end -lt 0) {
    throw "Could not determine end of paymentStatusFor method."
}

$newMethod = @'
static String paymentStatusFor(double paidAmount, double grandTotal) {
    // Compare money at paise precision so floating-point noise cannot
    // incorrectly turn a genuinely unpaid balance into PAID.
    final paidPaise = (paidAmount * 100).round();
    final totalPaise = (grandTotal * 100).round();

    if (paidPaise >= totalPaise) return 'PAID';
    if (paidPaise > 0) return 'PARTIAL';
    return 'UNPAID';
}
'@

$newContent = $content.Substring(0, $start) + $newMethod + $content.Substring($end + 1)
if ($newContent -ne $content) {
    [System.IO.File]::WriteAllText($saleFile, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated lib\sale_service.dart"
} else {
    Write-Host "sale_service.dart already had the desired paymentStatusFor implementation."
}

# --- widget_test.dart ---
if (Test-Path $widgetFile) {
    $w = [System.IO.File]::ReadAllText($widgetFile)

    $old = @'
  tearDown(() {
    // Nothing to clean up here yet.
  });
'@

    if ($w.Contains($old)) {
        $new = @'
  tearDown(() async {
    // Stop services that create timers/streams between widget tests.
    await SessionManagementService.stopPeriodicValidation();
    SyncService.dispose();
  });
'@
        $w = $w.Replace($old, $new)
        [System.IO.File]::WriteAllText($widgetFile, $w, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Updated test\widget_test.dart cleanup."
    } elseif ($w -match 'tearDown\(') {
        Write-Host "widget_test.dart already contains tearDown(); inspect it before changing anything."
    } else {
        Write-Host "No tearDown block found in widget_test.dart; no widget test changes made."
    }
} else {
    Write-Host "test\widget_test.dart not found; skipped widget-test edit."
}

Write-Host ""
Write-Host "Done. Now run:"
Write-Host "  flutter analyze"
Write-Host "  flutter test"
