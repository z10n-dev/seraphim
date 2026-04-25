#!/bin/bash

# Ordner erstellen, falls er fehlt
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

# Zeitstempel für den Dateinamen
NAME="Screenshot_$(date +%Y%m%d_%H%M%S)"
TEMP_FILE="/tmp/$NAME.png"
FINAL_FILE="$SAVE_DIR/$NAME-edited.png"

# 1. Screenshot machen (direkt in /tmp speichern, nicht über Pipe)
hyprshot -m region -o /tmp -f "$NAME.png" --silent

# 2. Prüfen, ob die Datei erstellt wurde
if [ -f "$TEMP_FILE" ]; then
    # 3. Satty starten mit dem Hardware-Beschleunigungs-Bypass
    GS_RENDERER=nglyph satty --filename "$TEMP_FILE" \
        --output-filename "$FINAL_FILE" \
        --early-exit
    
    # 4. Temp-Datei nach dem Schließen löschen
    rm "$TEMP_FILE"
else
    notify-send "Screenshot Fehler" "Die Aufnahme wurde abgebrochen oder schlug fehl."
fi