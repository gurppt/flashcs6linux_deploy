#!/usr/bin/env bash
# ============================================================================
#  Flash CS6 sous Linux (Wine) + pression tablette Huion — installeur
#
#  DEUX MODES, detectes automatiquement :
#   - HORS-LIGNE : si vendor/ est present (rempli par make-offline-bundle.sh),
#                  tout s'installe depuis vendor/ sans aucun acces internet.
#   - EN LIGNE   : sinon, telecharge ce qu'il faut (apt, winetricks, git).
#                  Dans ce cas WineHQ stable doit etre installe au prealable.
#
#  Pre-requis MANUELS dans les deux cas :
#    - deposer ton installeur Flash (ISO ou dossier extrait) dans local/
#    - deposer ton amtlib.dll dans local/
#
#  Usage :
#    ./install.sh             # tout
#    ./install.sh <phase>     # deps|prefix|flash|uclogic|xwintab|persist|desktop
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/settings.env
source "$HERE/config/settings.env"

WINEPREFIX_DIR="$(eval echo "$WINEPREFIX_DIR")"
FLASH_DIR="$WINEPREFIX_DIR/$FLASH_INSTALL_SUBDIR"
export WINEPREFIX="$WINEPREFIX_DIR"
export WINEARCH

OFFLINE=0
detect_mode() { if ls "$HERE"/vendor/debs/*.deb >/dev/null 2>&1; then OFFLINE=1; else OFFLINE=0; fi; }

say()   { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m%s\033[0m\n' "$*"; }
die()   { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }
pause() { warn "$*"; read -r -p $'\nEntree pour continuer... ' _; }

# Telecharge le pack (Wine + deps + cache winetricks + binaires pre-compiles)
# depuis la Release GitHub, UNE seule fois, et le met en cache dans vendor/.
# Si vendor/ est deja rempli (cache d'un run precedent, ou pack pre-place pour
# un deploiement 100% hors-ligne), rien n'est telecharge.
# Rend le pack disponible dans vendor/, dans cet ordre de priorite :
#   1. deja decompresse (cache d'un run precedent)         -> rien a faire
#   2. une archive flashcs6-pack.tar.gz est posee a cote   -> decompression AUTO
#   3. une URL de Release est definie + reseau dispo        -> telechargement
# L'utilisateur ne tape JAMAIS de commande tar : tout est automatique.
fetch_pack() {
  # 1) Deja en cache ?
  if ls "$HERE"/vendor/debs/*.deb >/dev/null 2>&1; then echo "Pack deja installe en cache (vendor/)."; return; fi

  # 2) Archive du pack posee localement (dossier du projet, ou vendor/) ?
  local arc=""
  for c in "$HERE"/flashcs6-pack.tar.gz "$HERE"/vendor/flashcs6-pack.tar.gz "$HERE"/flashcs6-pack*.tar.gz "$HERE"/*pack*.tar.gz; do
    [ -f "$c" ] && { arc="$c"; break; }
  done
  if [ -n "$arc" ]; then
    say "Pack trouve ($(basename "$arc")) -> decompression automatique dans vendor/"
    mkdir -p "$HERE/vendor"
    tar xzf "$arc" -C "$HERE/vendor"
    echo "Pack pret (aucun telechargement necessaire)."
    return
  fi

  # 3) Telechargement depuis la Release (si URL + reseau)
  if [ -z "${WINE_PACK_URL:-}" ]; then
    warn "Pas d'archive locale ni d'URL de pack -> mode SOURCE (build local ; Wine pre-requis)."
    return
  fi
  command -v curl >/dev/null || command -v wget >/dev/null || { warn "curl/wget absent -> pack non recuperable."; return; }
  say "Telechargement du pack depuis la Release..."
  mkdir -p "$HERE/vendor"
  local tgz="$HERE/vendor/_pack.tar.gz"
  if command -v curl >/dev/null; then
    curl -fL "$WINE_PACK_URL" -o "$tgz" || { warn "Echec du telechargement du pack."; rm -f "$tgz"; return; }
  else
    wget -O "$tgz" "$WINE_PACK_URL" || { warn "Echec du telechargement du pack."; rm -f "$tgz"; return; }
  fi
  tar xzf "$tgz" -C "$HERE/vendor" && rm -f "$tgz"
  echo "Pack mis en cache dans vendor/."
}

mode_banner() {
  if [ "$OFFLINE" = 1 ]; then say "MODE HORS-LIGNE (depuis vendor/)"; else say "MODE EN LIGNE"; fi
}

# ---------------------------------------------------------------------------
# Phase 0 — dependances (Wine + chaine de build OU rien si binaires pre-compiles)
# ---------------------------------------------------------------------------
phase_deps() {
  say "Phase 0 — dependances (sudo requis)"
  sudo dpkg --add-architecture i386
  if [ "$OFFLINE" = 1 ]; then
    echo "Installation des .deb depuis vendor/debs/ (sans internet)..."
    sudo dpkg -i "$HERE"/vendor/debs/*.deb 2>/dev/null || true
    # Resout l'ordre/les deps a partir des SEULS .deb locaux, sans rien telecharger
    sudo apt-get -f install -y --no-download || true
  else
    sudo apt-get update
    sudo apt-get install -y \
      gcc-multilib gcc-mingw-w64-i686-win32 \
      libxcb-xinput-dev:i386 libxcb1-dev:i386 \
      libusb-1.0-0-dev git make winetricks
    command -v wine >/dev/null || die "wine introuvable — installe WineHQ stable 11.0 (README)."
  fi
  command -v wine >/dev/null || die "wine toujours introuvable apres install."
  printf 'wine: '; wine --version || true
}

# ---------------------------------------------------------------------------
# Phase 1 — prefix Wine + winetricks + override DLL
# ---------------------------------------------------------------------------
phase_prefix() {
  say "Phase 1 — prefix Wine ($WINEPREFIX_DIR)"
  # En hors-ligne : pre-remplir le cache winetricks pour eviter tout telechargement
  if [ "$OFFLINE" = 1 ] && [ -d "$HERE/vendor/winetricks-cache" ]; then
    mkdir -p "$HOME/.cache/winetricks"
    cp -rn "$HERE/vendor/winetricks-cache/." "$HOME/.cache/winetricks/" 2>/dev/null || true
    echo "Cache winetricks pre-rempli."
  fi
  mkdir -p "$(dirname "$WINEPREFIX_DIR")"
  wineboot -u
  winetricks -q "$WIN_VERSION"
  winetricks -q corefonts vcrun2008 vcrun2010 msxml3 msxml6 \
                gdiplus atmlib riched20 riched30 fontsmooth=rgb
  wine reg add "HKCU\\Software\\Wine\\AppDefaults\\Flash.exe\\DllOverrides" \
       /v wintab32 /t REG_SZ /d "native,builtin" /f
}

# ---------------------------------------------------------------------------
# Phase 2 — installation de Flash CS6 (etape manuelle, TES fichiers)
# ---------------------------------------------------------------------------
phase_flash() {
  say "Phase 2 — installation de Flash CS6 (etape manuelle)"
  local iso installer mnt=""
  iso="$(ls $HERE/$LOCAL_ISO_GLOB 2>/dev/null | head -1 || true)"
  if [ -n "$iso" ]; then
    echo "ISO trouvee : $iso"
    mnt="$(mktemp -d)"
    sudo mount -o loop,ro "$iso" "$mnt"
    installer="$mnt/Set-up.exe"
    [ -f "$installer" ] || installer="$(ls "$mnt"/*.exe 2>/dev/null | head -1 || true)"
  else
    warn "Pas d'ISO dans local/. Indique le dossier extrait de l'installeur."
    read -r -p "Chemin complet du Set-up.exe : " installer
  fi
  [ -f "$installer" ] || die "Installeur introuvable."

  pause "RESEAU : coupe Internet maintenant (l'installeur tente de joindre des
serveurs Adobe hors-ligne depuis des annees, sinon il bloque).
Ensuite je lance l'installeur : choisis le mode d'essai (Try), installe,
et NE lance PAS Flash a la fin."
  wine "$installer" || true

  pause "Installation Adobe terminee ?
Etape de licence (la tienne, manuelle) : remplace l'amtlib.dll installe par TA copie.
   cp \"$HERE/$LOCAL_AMTLIB\"  \"$FLASH_DIR/amtlib.dll\"
Fais-le, puis continue."

  if [ -n "$mnt" ]; then sudo umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true; fi
  [ -f "$FLASH_DIR/Flash.exe" ] && echo "OK: $FLASH_DIR/Flash.exe present" \
    || warn "Attention: Flash.exe pas trouve dans $FLASH_DIR (verifie le chemin / settings.env)."
}

# ---------------------------------------------------------------------------
# Phase 3 — uclogic-tools (mode proprietaire = pression)
# ---------------------------------------------------------------------------
phase_uclogic() {
  say "Phase 3 — uclogic-tools"
  if command -v uclogic-probe >/dev/null; then echo "deja installe."; return; fi
  if [ -x "$HERE/vendor/uclogic/uclogic-probe" ]; then
    echo "Binaire pre-compile (vendor/)."
    sudo install -m755 "$HERE/vendor/uclogic/uclogic-probe"  /usr/local/bin/
    [ -f "$HERE/vendor/uclogic/uclogic-decode" ] && sudo install -m755 "$HERE/vendor/uclogic/uclogic-decode" /usr/local/bin/ || true
  else
    [ "$OFFLINE" = 1 ] && die "uclogic-probe absent de vendor/ (relance make-offline-bundle.sh)."
    local d; d="$(mktemp -d)"
    git clone https://github.com/DIGImend/uclogic-tools "$d/u"
    ( cd "$d/u" && make )
    sudo install -m755 "$d/u/uclogic-probe"  /usr/local/bin/
    sudo install -m755 "$d/u/uclogic-decode" /usr/local/bin/ 2>/dev/null || true
    rm -rf "$d"
  fi
}

# ---------------------------------------------------------------------------
# Phase 4 — XWinTab : binaires pre-compiles (vendor/) sinon build
# ---------------------------------------------------------------------------
phase_xwintab() {
  say "Phase 4 — XWinTab (wintab32.dll)"
  local sys32="$WINEPREFIX_DIR/drive_c/windows/system32"
  if [ -f "$HERE/vendor/xwintab/wintab32.dll" ]; then
    echo "Binaires pre-compiles (vendor/)."
    install -m644 "$HERE/vendor/xwintab/wintab32.dll"         "$sys32/wintab32.dll"
    install -m644 "$HERE/vendor/xwintab/XWinTabHelper.dll.so" "$sys32/XWinTabHelper.dll.so"
  else
    [ "$OFFLINE" = 1 ] && die "Binaires XWinTab absents de vendor/ (relance make-offline-bundle.sh)."
    [ -f "$HERE/xwintab/build32-def.sh" ] || die "xwintab/ vide. Copie ta source (xwintab/README.md)."
    ( cd "$HERE/xwintab" && ./build32-def.sh )
    install -m644 "$HERE/xwintab/wintab32.dll"         "$sys32/wintab32.dll"
    install -m644 "$HERE/xwintab/XWinTabHelper.dll.so" "$sys32/XWinTabHelper.dll.so"
  fi
  echo "wintab32.dll + helper deployes."
}

# ---------------------------------------------------------------------------
# Phase 5 — persistance mode proprietaire (systemd + udev)
# ---------------------------------------------------------------------------
phase_persist() {
  say "Phase 5 — persistance mode proprietaire (systemd + udev)"
  sed "s#@VID@#$TABLET_VID#g; s#@PID@#$TABLET_PID#g" "$HERE/system/huion-proprietary-mode.sh" \
    | sudo tee /usr/local/bin/huion-proprietary-mode.sh >/dev/null
  sudo chmod +x /usr/local/bin/huion-proprietary-mode.sh
  sudo install -m644 "$HERE/system/huion-proprietary-mode.service" /etc/systemd/system/huion-proprietary-mode.service
  sed "s#@VID@#$TABLET_VID#g; s#@PID@#$TABLET_PID#g" "$HERE/system/70-huion-proprietary-mode.rules" \
    | sudo tee /etc/udev/rules.d/70-huion-proprietary-mode.rules >/dev/null
  sudo systemctl daemon-reload
  sudo udevadm control --reload-rules
  sudo systemctl start huion-proprietary-mode.service || true
  sleep 2
  sudo tail -3 /var/log/huion-proprietary-mode.log 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Phase 6 — lanceur menu + mapping ecran
# ---------------------------------------------------------------------------
phase_desktop() {
  say "Phase 6 — lanceur menu (Graphics) + mapping ecran"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.config/autostart"
  sed "s#@WINEPREFIX@#$WINEPREFIX_DIR#g; s#@FLASHSUB@#$FLASH_INSTALL_SUBDIR#g" \
      "$HERE/desktop/flash-cs6" > "$HOME/.local/bin/flash-cs6"
  chmod +x "$HOME/.local/bin/flash-cs6"
  sed "s#@HOME@#$HOME#g; s#@WINEPREFIX@#$WINEPREFIX_DIR#g; s#@FLASHSUB@#$FLASH_INSTALL_SUBDIR#g" \
      "$HERE/desktop/flash-cs6.desktop" > "$HOME/.local/share/applications/flash-cs6.desktop"
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  sed "s#@OUTPUT@#$KAMVAS_OUTPUT#g" \
      "$HERE/desktop/huion-map.sh" > "$HOME/.local/bin/huion-map.sh"
  chmod +x "$HOME/.local/bin/huion-map.sh"
  cat > "$HOME/.config/autostart/huion-map.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Huion pen -> Kamvas
Exec=$HOME/.local/bin/huion-map.sh
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
  echo "Lanceur + autostart installes."
}

# ---------------------------------------------------------------------------
main() {
  local phase="${1:-all}"
  fetch_pack
  detect_mode
  mode_banner
  case "$phase" in
    deps) phase_deps ;; prefix) phase_prefix ;; flash) phase_flash ;;
    uclogic) phase_uclogic ;; xwintab) phase_xwintab ;;
    persist) phase_persist ;; desktop) phase_desktop ;;
    all)
      phase_deps; phase_prefix; phase_flash; phase_uclogic
      phase_xwintab; phase_persist; phase_desktop
      say "Termine. Reboot conseille, puis : Menu -> Graphics -> Adobe Flash CS6."
      ;;
    *) die "Phase inconnue: $phase" ;;
  esac
}
main "$@"
