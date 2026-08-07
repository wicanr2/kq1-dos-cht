set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /src
mkdir -p /out/shots
TAG="${TAG:-cht}"
timeout 90 ./scummvm --path=/game --auto-detect ${LANGOPT:---language=tw} --extrapath=/cht \
  --savepath=/saves --save-slot=4 2>/tmp/sv.log &
SV=$!
sleep 10
# 道具欄
xdotool key Tab 2>/dev/null || true; sleep 3
import -window root /out/shots/${TAG}_inv.png 2>/dev/null || true
xdotool key Return 2>/dev/null || true; sleep 2
# 選單列：Esc 叫出，往右走到「速度」與「音效」各展開一次
xdotool key Escape 2>/dev/null || true; sleep 2
import -window root /out/shots/${TAG}_menubar.png 2>/dev/null || true
xdotool key Right 2>/dev/null || true; sleep 1
xdotool key Right 2>/dev/null || true; sleep 1
xdotool key Right 2>/dev/null || true; sleep 1
import -window root /out/shots/${TAG}_menu_speed.png 2>/dev/null || true
xdotool key Right 2>/dev/null || true; sleep 2
import -window root /out/shots/${TAG}_menu_sound.png 2>/dev/null || true
xdotool key Escape 2>/dev/null || true; sleep 2
import -window root /out/shots/${TAG}_menu_closed.png 2>/dev/null || true
kill $SV 2>/dev/null || true
echo done
