#!/bin/sh
# Active le mode proprietaire Huion (pression pour wintab). Trouve la tablette
# elle-meme : bus/dev jamais codes en dur. (@VID@/@PID@ substitues a l'install.)
VID=@VID@
PID=@PID@
sleep 1
line=$(lsusb -d ${VID}:${PID} | head -1)
if [ -z "$line" ]; then echo "$(date): tablette ${VID}:${PID} absente"; exit 0; fi
bus=$(echo "$line" | awk '{print $2+0}')
dev=$(echo "$line" | awk '{print $4+0}')
echo "$(date): probe bus=$bus dev=$dev"
/usr/local/bin/uclogic-probe "$bus" "$dev" >/dev/null
echo "$(date): uclogic-probe exit=$?"
exit 0
