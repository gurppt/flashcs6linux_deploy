#!/usr/bin/env bash
# ============================================================================
#  make-offline-bundle.sh
#  A lancer UNE FOIS sur une machine qui MARCHE et qui est EN LIGNE,
#  sur la MEME version d'Ubuntu que la cible de deploiement.
#
#  Il remplit vendor/ avec tout le necessaire pour que install.sh tourne
#  ensuite HORS-LIGNE :
#    - vendor/debs/             : Wine + chaine de build + dependances (.deb)
#    - vendor/winetricks-cache/ : composants deja telecharges (corefonts, vcrun…)
#    - vendor/xwintab/          : wintab32.dll + XWinTabHelper.dll.so (pre-compiles)
#    - vendor/uclogic/          : uclogic-probe / uclogic-decode (pre-compiles)
#
#  vendor/ est gitignore : il ne part PAS dans le depot git. Pour distribuer la
#  capsule hors-ligne, fais-en un .tar (voir la fin du script) et mets-le dans
#  une Release GitHub (ou sur cle USB).
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/settings.env
source "$HERE/config/settings.env"

say() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

mkdir -p "$HERE/vendor/debs" "$HERE/vendor/winetricks-cache" \
         "$HERE/vendor/xwintab" "$HERE/vendor/uclogic"

# ---------------------------------------------------------------------------
# 1) Paquets .deb : Wine + chaine de build + leurs dependances
# ---------------------------------------------------------------------------
say "1/4 — Telechargement des .deb (Wine + dependances)"
sudo dpkg --add-architecture i386
sudo apt-get update

# Pack = Wine + libs RUNTIME uniquement. Les binaires XWinTab/uclogic sont
# pre-compiles plus bas, donc la chaine de build (mingw/gcc/xcb-dev) n'est PAS
# necessaire sur la machine cible et n'entre pas dans le pack.
PKGS="winehq-stable libxcb-xinput0 libusb-1.0-0 winetricks"

# On vide le cache apt local puis on FORCE le re-telechargement des paquets
# voulus + on calcule leur cloture de dependances (installees comprises), pour
# que le bundle soit complet meme sur une cible minimale.
echo "Calcul de la cloture de dependances..."
DEPS="$(apt-cache depends --recurse --no-recommends --no-suggests \
        --no-conflicts --no-breaks --no-replaces --no-enhances $PKGS 2>/dev/null \
        | grep '^\w' | sort -u || true)"

# Telecharge UNIQUEMENT la cloture calculee dans vendor/debs (apt-get download
# = sans installer). On NE copie SURTOUT PAS /var/cache/apt/archives : ce cache
# contient tout l'historique apt de la machine (COSMIC, GNOME, mises a jour
# Pop!_OS, vieux Wine...) = des centaines de Mo de dechets qui n'ont rien a faire
# dans le pack.
( cd "$HERE/vendor/debs" && apt-get download $PKGS $DEPS 2>/dev/null || true )
echo "  -> $(ls "$HERE/vendor/debs"/*.deb 2>/dev/null | wc -l) paquets .deb ($(du -sh "$HERE/vendor/debs" 2>/dev/null | cut -f1))"

# ---------------------------------------------------------------------------
# 2) Cache winetricks (composants Windows deja telecharges)
# ---------------------------------------------------------------------------
say "2/4 — Cache winetricks (uniquement les composants utilises)"
WT_CACHE="$HOME/.cache/winetricks"
# Whitelist : on ne prend QUE les sous-dossiers des verbes installes par
# install.sh (+ msls31, helper d'installeurs MS). On evite ainsi win7sp1,
# win2ksp4 et autres restes qui pesent des centaines de Mo pour rien.
WT_VERBS="corefonts vcrun2008 vcrun2010 msxml3 msxml6 gdiplus atmlib riched20 riched30 msls31"
if [ -d "$WT_CACHE" ]; then
  for v in $WT_VERBS; do
    [ -d "$WT_CACHE/$v" ] && cp -r "$WT_CACHE/$v" "$HERE/vendor/winetricks-cache/"
  done
  echo "  -> $(du -sh "$HERE/vendor/winetricks-cache" 2>/dev/null | cut -f1) de cache utile."
else
  echo "  !! Cache winetricks introuvable. Lance d'abord une install winetricks complete"
  echo "     (les memes verbes que install.sh) pour le remplir, puis relance ce script."
fi

# ---------------------------------------------------------------------------
# 3) XWinTab pre-compile (DLL PE + helper winelib)
# ---------------------------------------------------------------------------
say "3/4 — Compilation + capture des binaires XWinTab"
[ -f "$HERE/xwintab/build32-def.sh" ] || { echo "!! xwintab/ vide (copie ta source d'abord)"; exit 1; }
( cd "$HERE/xwintab" && ./build32-def.sh )
cp "$HERE/xwintab/wintab32.dll"         "$HERE/vendor/xwintab/"
cp "$HERE/xwintab/XWinTabHelper.dll.so" "$HERE/vendor/xwintab/"
echo "  -> wintab32.dll + XWinTabHelper.dll.so captures."
echo "  NB: le helper .so est lie a CETTE version de Wine -> deploie avec le meme Wine (vendor/debs)."

# ---------------------------------------------------------------------------
# 4) uclogic-tools pre-compile
# ---------------------------------------------------------------------------
say "4/4 — uclogic-tools pre-compile"
if [ -x /usr/local/bin/uclogic-probe ]; then
  sudo cp /usr/local/bin/uclogic-probe  "$HERE/vendor/uclogic/"
  sudo cp /usr/local/bin/uclogic-decode "$HERE/vendor/uclogic/" 2>/dev/null || true
  sudo chown "$USER":"$USER" "$HERE/vendor/uclogic/"*
else
  d="$(mktemp -d)"
  git clone https://github.com/DIGImend/uclogic-tools "$d/u"
  ( cd "$d/u" && make )
  cp "$d/u/uclogic-probe" "$d/u/uclogic-decode" "$HERE/vendor/uclogic/"
  rm -rf "$d"
fi
echo "  -> uclogic-probe capture."

# ---------------------------------------------------------------------------
say "Creation de l'archive du pack"
PACK="$HERE/flashcs6-pack.tar.gz"
tar czf "$PACK" -C "$HERE/vendor" .
echo "Pack cree : $PACK"; du -sh "$PACK"
echo
echo "Etapes suivantes :"
echo "  1) Cree une Release sur GitHub et joins-y  flashcs6-pack.tar.gz"
echo "  2) Copie l'URL du .tar.gz dans config/settings.env  ->  WINE_PACK_URL=\"...\""
echo
echo "Ensuite, sur n'importe quelle machine de MEME base Ubuntu :"
echo "  git clone <repo> ; deposer ses fichiers dans local/ ; ./install.sh"
echo "install.sh telecharge le pack une fois, le met en cache dans vendor/, et"
echo "installe tout hors-ligne (Wine + composants + binaires)."
