#!/usr/bin/env bash
# cat_ocean_flow 쇼케이스 씬을 Movie Maker로 녹화해 docs/media/cat_ocean_flow/ 에 mp4·gif로 만든다.
# 사용: tools/record_cat_ocean_flow.sh            (전체)
#       tools/record_cat_ocean_flow.sh 05_waves   (해당 씬만, 여러 개 가능)
# 깊이 기반 포말이 보이도록 임시 프로젝트 렌더러는 Forward Plus(Compatibility 금지). mp4는 용량 때문에 30fps로 낮춘다.
# 환경변수: GODOT(Godot 실행 파일), FFMPEG(기본 /opt/homebrew/bin/ffmpeg), ADDONS_DIR(기본 <repo>/addons), OUT_DIR(기본 docs/media/cat_ocean_flow)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Users/woody/dev/Godo_Project/Godot_v4.7.2-stable_macos.universal/Godot.app/Contents/MacOS/Godot}"
FFMPEG="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"
SCENE_DIR="$REPO/demo/cat_ocean_flow/showcase"
OUT_DIR="${OUT_DIR:-$REPO/docs/media/cat_ocean_flow}"
ADDONS_DIR="${ADDONS_DIR:-$REPO/addons}"
FPS=60

[[ -x "$GODOT" ]] || { echo "GODOT 실행 파일 없음: $GODOT" >&2; exit 1; }
[[ -x "$FFMPEG" ]] || { echo "ffmpeg 없음: $FFMPEG" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT_DIR"

# 레포 project.godot의 창 크기(1152x648)를 건드리지 않도록 1280x720 임시 프로젝트에 addons·demo를 연결해 녹화한다.
PROJ="$TMP/proj"
mkdir -p "$PROJ"
ln -s "$ADDONS_DIR" "$PROJ/addons"
ln -s "$REPO/demo" "$PROJ/demo"
cat > "$PROJ/project.godot" <<'CFG'
config_version=5

[application]
config/name="cat_ocean_flow showcase"
config/features=PackedStringArray("4.7", "Forward Plus")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[editor_plugins]
enabled=PackedStringArray()
CFG
"$GODOT" --headless --path "$PROJ" --import >"$TMP/import.log" 2>&1 || true

if [[ $# -gt 0 ]]; then
  SCENES=("$@")
else
  SCENES=()
  for f in "$SCENE_DIR"/[0-9][0-9]_*.tscn; do SCENES+=("$(basename "$f" .tscn)"); done
fi

for name in "${SCENES[@]}"; do
  scene="$SCENE_DIR/$name.tscn"
  [[ -f "$scene" ]] || { echo "씬 없음: $name" >&2; exit 1; }
  # 길이는 씬 스크립트의 const DURATION(초)에서 읽는다.
  duration="$(sed -n 's/^const DURATION := \([0-9.]*\).*/\1/p' "$SCENE_DIR/$name.gd" | head -1)"
  [[ -n "$duration" ]] || { echo "DURATION 없음: $name" >&2; exit 1; }
  frames="$(awk -v d="$duration" -v f="$FPS" 'BEGIN { printf "%d", d * f }')"

  echo "== $name (${duration}s, ${frames}프레임)"
  # 창이 가려지거나 시스템이 바쁘면 렌더가 멈춘 채 프레임이 복제되는 경우가 있어,
  # 같은 결과가 연속 두 번 나올 때까지(최대 4회) 다시 녹화한다.
  prev=""
  accepted=0
  for attempt in 1 2 3 4; do
    "$GODOT" --path "$PROJ" --always-on-top --write-movie "$TMP/$name.avi" --fixed-fps "$FPS" --quit-after "$frames" \
      "res://demo/cat_ocean_flow/showcase/$name.tscn" >"$TMP/$name.log" 2>&1
    if grep -E 'SCRIPT ERROR|Parse Error|ERROR:' "$TMP/$name.log"; then
      echo "오류 발생: $name" >&2
      exit 1
    fi
    cur="$("$FFMPEG" -v error -i "$TMP/$name.avi" -f framemd5 - | grep -v '^#' | awk -F, '{print $NF}' | md5)"
    if [[ "$cur" == "$prev" ]]; then accepted=1; break; fi
    prev="$cur"
    echo "   재녹화 검증 중 (시도 $attempt)"
  done
  [[ "$accepted" == 1 ]] || echo "경고: $name 결과가 일관되지 않음(마지막 시도 사용)" >&2

  # 물 노이즈는 압축이 잘 안 되므로 mp4 2MB·gif 3MB 이하가 될 때까지 품질을 단계적으로 낮춘다.
  for crf in "${CRF:-26}" 29 32 35; do
    "$FFMPEG" -v error -y -i "$TMP/$name.avi" -an -c:v libx264 -pix_fmt yuv420p -crf "$crf" \
      -movflags +faststart -r 30 "$OUT_DIR/$name.mp4"
    [[ "$(stat -f %z "$OUT_DIR/$name.mp4")" -le 2097152 ]] && break
  done
  for opt in "${GIF_FPS:-12}:${GIF_COLORS:-64}" 10:48 8:32 8:24 6:24 6:16; do
    gfps="${opt%%:*}"; gcol="${opt##*:}"
    "$FFMPEG" -v error -y -i "$TMP/$name.avi" \
      -vf "fps=$gfps,scale=640:-1:flags=lanczos,palettegen=max_colors=$gcol:stats_mode=diff" "$TMP/$name.png"
    "$FFMPEG" -v error -y -i "$TMP/$name.avi" -i "$TMP/$name.png" \
      -lavfi "fps=$gfps,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" \
      "$OUT_DIR/$name.gif"
    [[ "$(stat -f %z "$OUT_DIR/$name.gif")" -le 3145728 ]] && break
  done
  ls -l "$OUT_DIR/$name.mp4" "$OUT_DIR/$name.gif" | awk '{printf "   %s %.0fKB\n", $NF, $5/1024}'
done
