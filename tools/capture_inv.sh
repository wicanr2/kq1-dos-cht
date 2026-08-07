set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /src
mkdir -p /out/shots
LANGOPT="${LANGOPT:---language=tw}"
TAG="${TAG:-cht}"
for SLOT in ${SLOTS:-1 2 3 4}; do
  timeout 40 ./scummvm --path=/game --auto-detect $LANGOPT --extrapath=/cht \
    --savepath=/saves --save-slot=$SLOT 2>>/tmp/sv.log &
  SV=$!
  sleep 10
  import -window root /out/shots/${TAG}_s${SLOT}_room.png 2>/dev/null || true
  xdotool key Tab 2>/dev/null || true; sleep 3
  import -window root /out/shots/${TAG}_s${SLOT}_inv.png 2>/dev/null || true
  kill $SV 2>/dev/null || true
  sleep 3
done
echo "=== stderr tail ==="; tail -5 /tmp/sv.log
