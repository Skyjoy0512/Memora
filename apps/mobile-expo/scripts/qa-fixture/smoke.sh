#!/bin/bash
# 実データフィクスチャで RN ホストの表示を検証する。
#
#   MEMORA_QA_FIXTURE=~/Desktop/memora-verify ./smoke.sh
#
# フィクスチャ（実会議の音声・文字起こし）は個人情報を含むためリポジトリには置かない。
# ディレクトリに音声(.mp3/.m4a)と "*transcript.txt" を入れ、パスを環境変数で渡すこと。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${MEMORA_QA_FIXTURE:?MEMORA_QA_FIXTURE にフィクスチャのディレクトリを指定してください}"
UDID="${MEMORA_QA_SIMULATOR:-booted}"
BUNDLE_ID="${MEMORA_QA_BUNDLE_ID:-com.anonymous.memora-rn}"
OUT_DIR="${MEMORA_QA_OUT:-$SCRIPT_DIR/../../.expo/qa-screenshots}"
TITLE="${MEMORA_QA_TITLE:-【QA】実データフィクスチャ}"

mkdir -p "$OUT_DIR"
AUDIO="$(find "$FIXTURE" -maxdepth 1 \( -name '*.mp3' -o -name '*.m4a' \) | head -1)"
TRANSCRIPT="$(find "$FIXTURE" -maxdepth 1 -name '*transcript.txt' | head -1)"
[ -n "$AUDIO" ] || { echo "音声ファイルが見つかりません: $FIXTURE" >&2; exit 1; }

echo "==> フィクスチャ"
echo "    音声      : $AUDIO"
echo "    文字起こし: ${TRANSCRIPT:-（なし: 未文字起こしとして投入）}"

DURATION="$(python3 -c "
import subprocess, sys
out = subprocess.run(['afinfo', sys.argv[1]], capture_output=True, text=True).stdout
for line in out.splitlines():
    if 'estimated duration' in line:
        print(line.split(':')[1].strip().split()[0]); break
" "$AUDIO")"
echo "    長さ      : ${DURATION}s"

SEGMENTS="$(mktemp -t memora-qa-segments).json"
trap 'rm -f "$SEGMENTS"' EXIT
if [ -n "$TRANSCRIPT" ]; then
  python3 "$SCRIPT_DIR/parse_transcript.py" "$TRANSCRIPT" "$DURATION" "$SEGMENTS"
else
  echo '[]' > "$SEGMENTS"
fi

echo "==> App Group を解決"
APP_GROUP="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" group.com.memora.shared)"
echo "    $APP_GROUP"

echo "==> アプリを終了して投入（SQLite ロック回避）"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
FILE_ID="$(swift run --package-path "$SCRIPT_DIR/Seeder" Seeder \
  "$APP_GROUP" "$AUDIO" "$SEGMENTS" "$TITLE" ${TRANSCRIPT:+"$TRANSCRIPT"} | tail -1)"
echo "    AudioFile id = $FILE_ID"

echo "==> 起動して詳細画面へ遷移"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
# Debug ビルドは Metro からバンドルを取得するため、初回起動は描画まで時間がかかる。
sleep "${MEMORA_QA_LAUNCH_WAIT:-25}"
xcrun simctl io "$UDID" screenshot "$OUT_DIR/01-list.png" >/dev/null 2>&1

# ディープリンクは描画完了前だと取りこぼすため、間隔を空けて 2 回送る。
xcrun simctl openurl "$UDID" "memora-rn://file/$FILE_ID"
sleep 5
xcrun simctl openurl "$UDID" "memora-rn://file/$FILE_ID"
sleep "${MEMORA_QA_DETAIL_WAIT:-8}"
xcrun simctl io "$UDID" screenshot "$OUT_DIR/02-detail.png" >/dev/null 2>&1

echo "==> 完了"
echo "    スクリーンショット: $OUT_DIR"
echo "    確認してください: 再生バーの総時間が音声の長さと一致するか / 文字起こしが時刻付きで並ぶか"
