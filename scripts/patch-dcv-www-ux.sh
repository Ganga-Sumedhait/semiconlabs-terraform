#!/bin/bash
# Idempotent: patch NICE DCV web client for lab UX on already-running instances.
# - Replaces "The connection has been closed" with a duplicate-session hint.
# - Injects custom-popup.js (Stop Lab reminder on first opens).
#
# Manual use (SSM agent Online, LabSSMRole on instance):
#   aws ssm send-command \
#     --instance-ids i-xxxxxxxx \
#     --document-name AWS-RunShellScript \
#     --parameters commands="$(sed 's/$/\\n/' patch-dcv-www-ux.sh | tr -d '\n')" \
#     --comment "one-time DCV www UX patch"
#
# Or upload this file to the instance and run: sudo bash patch-dcv-www-ux.sh
set -u

MARKER=/etc/lab/dcv-www-ux-v1.done
LOG_TAG="[dcv-ux-patch]"

log() { echo "$LOG_TAG $*"; }

if [ -f "$MARKER" ]; then
  log "already applied ($(cat "$MARKER" 2>/dev/null || echo ok))"
  exit 0
fi

if [ ! -d /usr/share/dcv/www ]; then
  log "ERROR: /usr/share/dcv/www not found"
  exit 1
fi

DCV_DUP_MSG='You already have an active lab session in another browser tab or window. Please log out from that session first, then try again here.'

find /usr/share/dcv/www -type f \( -name '*.js' -o -name '*.html' -o -name '*.json' \) \
  -exec sed -i "s|The connection has been closed\.|${DCV_DUP_MSG}|g" {} + 2>/dev/null || true
find /usr/share/dcv/www -type f \( -name '*.js' -o -name '*.html' -o -name '*.json' \) \
  -exec sed -i "s|The connection has been closed|${DCV_DUP_MSG}|g" {} + 2>/dev/null || true

cat >/usr/share/dcv/www/custom-popup.js <<'DCVPOP'
if(!window.__lab_stop_hint_shown){window.__lab_stop_hint_shown=1;try{var n=parseInt(localStorage.getItem("lab_warn_count")||"0",10);if(n<3){localStorage.setItem("lab_warn_count",String(n+1));alert("Important: Closing this browser tab does NOT stop your lab session. It keeps running in the background. When you are done, click Stop Lab on the main portal.");}}catch(e){}}
DCVPOP
chmod 644 /usr/share/dcv/www/custom-popup.js || true

if [ -f /usr/share/dcv/www/index.html ] && ! grep -q custom-popup.js /usr/share/dcv/www/index.html 2>/dev/null; then
  sed -i 's|</head>|<script src="custom-popup.js"></script></head>|' /usr/share/dcv/www/index.html 2>/dev/null || true
fi

systemctl restart dcvserver 2>/dev/null || true

install -d /etc/lab
date -u +%Y-%m-%dT%H:%M:%SZ >"$MARKER"
log "done marker=$MARKER"
exit 0
