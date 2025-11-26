@echo off
echo 🔧 Running Dart formatter...
dart format .

if %errorlevel% equ 0 (
    echo ✅ Dart formatting completed successfully
) else (
    echo ❌ Dart formatting failed
    exit /b 1
)

echo 🔍 Running Flutter analyze...
flutter analyze --no-fatal-infos

if %errorlevel% equ 0 (
    echo ✅ Flutter analyze completed successfully
) else (
    echo ⚠️  Flutter analyze found issues (non-fatal)
)

echo 🚀 Formatting and analysis completed!
pause
