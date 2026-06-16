#!/bin/sh
# Restreint le stylet Huion a l'ecran @OUTPUT@.
# Le nom du device n'est PAS stable entre boots (mode proprietaire :
# "...Pen (0)" ou "...Pen Pen (0)") -> recherche dynamique (Huion + "(0)").
for i in $(seq 1 30); do
  PEN=$(xinput list --name-only 2>/dev/null | grep -i huion | grep -F "(0)" | head -1)
  if [ -n "$PEN" ]; then
    xinput map-to-output "$PEN" @OUTPUT@
    break
  fi
  sleep 1
done
