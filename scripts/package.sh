#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "需要在 macOS 上執行。" >&2
    exit 1
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "請先安裝並開啟完整 Xcode，完成首次設定；只有 Command Line Tools 不足以編譯。" >&2
    exit 1
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${CONFIGURATION:-Release}"
case "$configuration" in
    Debug|Release) ;;
    *) echo "CONFIGURATION 僅接受 Debug 或 Release。" >&2; exit 1 ;;
esac

build_dir="$project_root/build/package"
output_dir="$project_root/dist"
app_path="$build_dir/Build/Products/$configuration/LiveTranslator.app"
archive_path="$output_dir/LiveTranslator.zip"

printf '正在編譯 %s（本機 ad-hoc 簽署，不需付費開發者帳號）…\n' "$configuration"
xcodebuild -quiet \
    -project "$project_root/LiveTranslator.xcodeproj" \
    -scheme LiveTranslator \
    -configuration "$configuration" \
    -destination 'platform=macOS' \
    -derivedDataPath "$build_dir" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    build

if [[ ! -d "$app_path" ]]; then
    echo "找不到編譯成品：$app_path" >&2
    exit 1
fi
mkdir -p "$output_dir"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"
printf '\n完成。\nApp：%s\nZIP：%s\n\n啟動指令：\nopen "%s"\n' "$app_path" "$archive_path" "$app_path"
