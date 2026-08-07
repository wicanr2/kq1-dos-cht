set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /src
mkdir -p /out/shots
TAG="${TAG:-soak}"
timeout 260 ./scummvm --path=/game --auto-detect ${LANGOPT:---language=tw} --extrapath=/cht \
  --savepath=/saves --save-slot=4 2>/tmp/sv.log &
SV=$!
sleep 10
i=0
snap() { i=$((i+1)); import -window root "$(printf '/out/shots/%s_%02d_%s.png' "$TAG" "$i" "$1")" 2>/dev/null || true; }
snap start
# 連續換場景：四個方向各走一段，每段截兩張
for dir in Right Right Down Down Left Left Up Up Right Down; do
  xdotool key $dir 2>/dev/null || true
  sleep 5; snap walk_$dir
  sleep 5; snap settle_$dir
done
# 視窗類：F1 說明、道具欄
xdotool key F1 2>/dev/null || true; sleep 3; snap f1
xdotool key Return 2>/dev/null || true; sleep 2; snap f1closed
xdotool key Tab 2>/dev/null || true; sleep 3; snap inv
xdotool key Return 2>/dev/null || true; sleep 2; snap invclosed
# 再換一次場景，確認關窗後狀態列仍完整
xdotool key Left 2>/dev/null || true; sleep 6; snap after_left
kill $SV 2>/dev/null || true
echo done
