# Les 7 correctifs XWinTab (pour Flash / Animate)

XWinTab d'origine (Graham--M) cible Rebelle. Flash CS6 exerce des chemins de code
que Rebelle n'utilise jamais, révélant 6 bugs + 1 manque. Corrigés ici :

1. **Ordinaux Wintab** — Flash résout les fonctions wintab *par ordinal*, pas par
   nom. Ajout d'un `src/wintab32.def` avec les ordinaux canoniques de la spec
   (WTInfoW@1020, WTOpenW@1021, WTGetW@1061, WTClose@22, WTPacketsGet@23,
   WTPacketsPeek@80, WTEnable@40, WTOverlap@41, WTQueueSizeGet@84, WTQueueSizeSet@85)
   et build avec ce `.def` (au lieu de `--kill-at`).

2. **Acceptation du stylet sans bouton** (`check_device`) — exigeait
   `num_buttons > 0`. Le pen Huion expose 0 bouton sous libinput (ils sont sur le
   PAD). Assoupli : on n'exige que `valuator_info && axes >= 3` ; `nButtons` gardé.

3. **WTInfoW(0,0)** — Flash sonde la présence tablette via `WTInfoW(0,0)` ; était
   "unhandled" -> 0 -> "pas de tablette". Ajout du handler (retourne la taille du
   LOGCONTEXTW si un device est sélectionné).

4. **WTI_DEVICES (capacités)** — Flash interroge `DVC_PKTDATA/CSRDATA/X/Y/NPRESSURE`
   pour activer l'UI de pression ; non gérées. Ajout du bloc `cat==WTI_DEVICES`
   (masque WTPKT + structs AXIS X/Y/NPRESSURE, max de pression depuis le device).

5. **Typo `pkt_peek_itr`** (WTPacketsPeek) — `(PktPeekIterData *) data` (cast sur
   soi-même -> pointeur non initialisé). Crash : lecture à l'adresse 0x8 (membre
   `dst`, offset 8). Corrigé en `(PktPeekIterData *) userData`.

6. **WTPacketsPeek garde NULL** — Flash appelle WTPacketsPeek avec un buffer NULL
   pour *compter* les packets ; `packet_copy` écrivait alors vers 0x0. Crash :
   écriture à l'adresse 0x0. Gardé : `if (data->dst) ...` (comme WTPacketsGet).

7. **Re-bind de contexte dans WTOpen** — Flash ré-ouvre un contexte à chaque
   nouveau document sans jamais appeler WTClose. L'ancien garde `if (g_context.handle
   ...) return NULL` renvoyait NULL -> nouveau doc sans pression. Corrigé : si un
   contexte existe déjà, re-bind sur la nouvelle fenêtre (sous g_lock) et renvoie le
   handle existant. (Symptôme d'origine : la pression disparaissait dès que Flash
   se retrouvait sans aucun document ouvert.)
