Write-Host "🔧 Running Dart formatter..." -ForegroundColor Cyan

# Format all Dart files
dart format .

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Dart formatting completed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Dart formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "🔍 Running Flutter analyze..." -ForegroundColor Cyan
flutter analyze --no-fatal-infos

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Flutter analyze completed successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️  Flutter analyze found issues (non-fatal)" -ForegroundColor Yellow
}

Write-Host "🚀 Formatting and analysis completed!" -ForegroundColor Green
