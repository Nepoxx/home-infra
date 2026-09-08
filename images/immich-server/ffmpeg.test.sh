#!/usr/bin/env bash
# Self-test for the ffmpeg shim. Stubs the real ffmpeg and checks the
# rewritten args. Run: bash images/immich-server/ffmpeg.test.sh
set -euo pipefail
cd "$(dirname "$0")"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Stub ffmpeg that prints its args one per line
cat > "$tmp/ffmpeg" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do printf '%s\n' "$a"; done
EOF
chmod +x "$tmp/ffmpeg"
export FFMPEG_BIN="$tmp/ffmpeg"

fail=0

check() {
  local desc="$1" expected="$2"; shift 2
  local actual
  actual=$(./ffmpeg "$@" | tr '\n' '|')
  if [[ "$actual" == *"${expected}"* ]]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc"
    echo "  args: $actual"
    echo "  want substring: $expected"
    fail=1
  fi
}

check_no_inject() {
  local desc="$1"; shift 1
  local actual
  actual=$(./ffmpeg "$@" | tr '\n' '|')
  if [[ "$actual" == *"nv12"* ]]; then
    echo "FAIL: $desc (nv12 injected but should not be)"
    echo "  args: $actual"
    fail=1
  else
    echo "ok: $desc"
  fi
}

# 1. sw decode + vaapi encode, no -vf: append -vf format=nv12,hwupload
check "no -vf gets format=nv12,hwupload appended" \
  "-vf|format=nv12,hwupload|" \
  -hwaccel vaapi -i in.mp4 -c:v hevc_vaapi -c:a aac out.mp4

# 2. existing -vf without hwupload: append ,format=nv12,hwupload
check "existing -vf gets nv12 appended" \
  "scale=-2:720,format=nv12,hwupload|" \
  -hwaccel vaapi -i in.mp4 -vf scale=-2:720 -c:v h264_vaapi out.mp4

# 3. existing -vf with hwupload: insert before it
check "nv12 inserted before existing hwupload" \
  "scale=-2:720,format=nv12,hwupload|" \
  -hwaccel vaapi -i in.mp4 -vf scale=-2:720,hwupload -c:v h264_vaapi out.mp4

# 4. hw decode (hwaccel_output_format vaapi): untouched
check_no_inject "hw decode path untouched" \
  -hwaccel vaapi -hwaccel_output_format vaapi -i in.mp4 -c:v hevc_vaapi out.mp4

# 5. non-vaapi encoder: untouched
check_no_inject "cpu encoder untouched" \
  -hwaccel vaapi -i in.mp4 -vf scale=-2:720 -c:v libx264 out.mp4

# 6. -filter:v alias also handled
check "-filter:v alias handled" \
  "format=nv12,hwupload|" \
  -hwaccel vaapi -i in.mp4 -filter:v null -c:v hevc_vaapi out.mp4

exit "$fail"
