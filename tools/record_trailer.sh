#!/usr/bin/env bash
# CAT Text FX 트레일러(demo/cat_text_fx/trailer/trailer.tscn)를 Movie Maker로 녹화해
# docs/media/cat_text_fx/ 에 trailer.mp4(1920x1080), trailer_square.mp4(1080x1080), trailer_poster.png를 만든다.
# 사용: tools/record_trailer.sh
# 환경변수: GODOT, FFMPEG(기본 /opt/homebrew/bin/ffmpeg), ADDONS_DIR(기본 <repo>/addons), OUT_DIR(기본 docs/media/cat_text_fx),
#          KEEP_AVI(경로를 주면 원본 AVI를 그 경로로 복사; 프레임 확인용)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Users/woody/dev/Godo_Project/Godot_v4.7.2-stable_macos.universal/Godot.app/Contents/MacOS/Godot}"
FFMPEG="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"
SCENE_DIR="$REPO/demo/cat_text_fx/trailer"
OUT_DIR="${OUT_DIR:-$REPO/docs/media/cat_text_fx}"
ADDONS_DIR="${ADDONS_DIR:-$REPO/addons}"
FPS=60
MAX_BYTES=$((15 * 1024 * 1024))
POSTER_TIME=3.7   # 타이틀 등장이 끝나고 임팩트 전

[[ -x "$GODOT" ]] || { echo "GODOT 실행 파일 없음: $GODOT" >&2; exit 1; }
[[ -x "$FFMPEG" ]] || { echo "ffmpeg 없음: $FFMPEG" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT_DIR"

# 레포 project.godot의 창 크기를 건드리지 않도록 1920x1080 임시 프로젝트에 addons·demo를 연결해 녹화한다.
PROJ="$TMP/proj"
mkdir -p "$PROJ"
ln -s "$ADDONS_DIR" "$PROJ/addons"
ln -s "$REPO/demo" "$PROJ/demo"
cat > "$PROJ/project.godot" <<'CFG'
config_version=5

[application]
config/name="cat_text_fx trailer"
config/features=PackedStringArray("4.7", "Forward Plus")

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080

[editor_plugins]
enabled=PackedStringArray()
CFG
"$GODOT" --headless --path "$PROJ" --import >"$TMP/import.log" 2>&1 || true
if grep -E 'SCRIPT ERROR|Parse Error|ERROR:' "$TMP/import.log"; then
  echo "임포트 오류" >&2
  exit 1
fi

check_log() {
  if grep -E 'SCRIPT ERROR|Parse Error|ERROR:' "$1"; then
    echo "오류 발생: $1" >&2
    exit 1
  fi
}

duration="$(sed -n 's/^const DURATION := \([0-9.]*\).*/\1/p' "$SCENE_DIR/trailer.gd" | head -1)"
[[ -n "$duration" ]] || { echo "DURATION 없음" >&2; exit 1; }
frames="$(awk -v d="$duration" -v f="$FPS" 'BEGIN { printf "%d", d * f }')"
AVI="$TMP/trailer.avi"

echo "== trailer (${duration}s, ${frames}프레임)"
# 창이 가려지거나 시스템이 바쁘면 렌더가 멈춘 채 프레임이 복제되는 경우가 있어,
# 같은 결과가 연속 두 번 나올 때까지(최대 4회) 다시 녹화한다.
prev=""
accepted=0
for attempt in 1 2 3 4; do
  "$GODOT" --path "$PROJ" --always-on-top --resolution 1920x1080 --write-movie "$AVI" --fixed-fps "$FPS" \
    --quit-after "$frames" "res://demo/cat_text_fx/trailer/trailer.tscn" >"$TMP/trailer.log" 2>&1
  check_log "$TMP/trailer.log"
  cur="$("$FFMPEG" -v error -i "$AVI" -f framemd5 - | grep -v '^#' | awk -F, '{print $NF}' | md5)"
  if [[ "$cur" == "$prev" ]]; then accepted=1; break; fi
  prev="$cur"
  echo "   재녹화 검증 중 (시도 $attempt)"
done
[[ "$accepted" == 1 ]] || echo "경고: 결과가 일관되지 않음(마지막 시도 사용)" >&2
[[ -n "${KEEP_AVI:-}" ]] && cp "$AVI" "$KEEP_AVI"

# 가로판: 용량 상한(15MB)을 넘으면 crf를 올려 다시 인코딩한다.
for crf in 20 22 24 26; do
  # Movie Maker AVI(MJPEG)는 풀레인지라 일반 플레이어 호환을 위해 TV 레인지 yuv420p로 바꾼다.
  "$FFMPEG" -v error -y -i "$AVI" -an -vf "scale=in_range=pc:out_range=tv,format=yuv420p" \
    -c:v libx264 -profile:v high -pix_fmt yuv420p -color_range tv -crf "$crf" \
    -movflags +faststart -r "$FPS" "$OUT_DIR/trailer.mp4"
  bytes="$(stat -f %z "$OUT_DIR/trailer.mp4")"
  [[ "$bytes" -le "$MAX_BYTES" ]] && break
  echo "   ${bytes}B > 15MB, crf 올림"
done

# 포스터: 타이틀 장면 1프레임.
"$FFMPEG" -v error -y -ss "$POSTER_TIME" -i "$AVI" -frames:v 1 "$OUT_DIR/trailer_poster.png"

# 정사각판: 위아래 남색 틀(제목·링크)을 1080x1080 임시 프로젝트에서 Godot으로 한 장 찍고,
# 1080 폭으로 줄인 본편(1080x608)을 가운데(y=236)에 얹는다.
SQ="$TMP/proj_sq"
mkdir -p "$SQ"
ln -s "$ADDONS_DIR" "$SQ/addons"
ln -s "$REPO/demo" "$SQ/demo"
sed -e 's/viewport_width=1920/viewport_width=1080/' -e 's/trailer"/trailer square"/' "$PROJ/project.godot" > "$SQ/project.godot"
"$GODOT" --headless --path "$SQ" --import >"$TMP/import_sq.log" 2>&1 || true
"$GODOT" --path "$SQ" --always-on-top --write-movie "$TMP/frame.png" --fixed-fps "$FPS" \
  --quit-after 5 "res://demo/cat_text_fx/trailer/square_frame.tscn" >"$TMP/frame.log" 2>&1
check_log "$TMP/frame.log"
FRAME_PNG="$(ls "$TMP"/frame*.png | sort | tail -1)"
[[ -n "${KEEP_AVI:-}" ]] && cp "$FRAME_PNG" "${KEEP_AVI%.*}_square_frame.png"
for crf in 20 22 24 26; do
  "$FFMPEG" -v error -y -i "$AVI" -loop 1 -framerate "$FPS" -i "$FRAME_PNG" \
    -filter_complex "[0:v]scale=1080:608:flags=lanczos:in_range=pc:out_range=tv[v];[1:v]scale=1080:1080:out_range=tv,format=yuv420p[b];[b][v]overlay=0:236:shortest=1,format=yuv420p" \
    -an -c:v libx264 -profile:v high -pix_fmt yuv420p -color_range tv -crf "$crf" -movflags +faststart -r "$FPS" "$OUT_DIR/trailer_square.mp4"
  bytes="$(stat -f %z "$OUT_DIR/trailer_square.mp4")"
  [[ "$bytes" -le "$MAX_BYTES" ]] && break
  echo "   정사각 ${bytes}B > 15MB, crf 올림"
done

ls -l "$OUT_DIR/trailer.mp4" "$OUT_DIR/trailer_square.mp4" "$OUT_DIR/trailer_poster.png" | awk '{printf "   %s %.0fKB\n", $NF, $5/1024}'
