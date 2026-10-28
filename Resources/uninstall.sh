#!/bin/bash
# Uninstalls HomePad: brings the Dock back if HomePad hid it, takes back its permissions, erases its settings and
# categories, moves the app to the Trash and forgets the installer's record. HomePad's menu-bar menu (right-click the
# icon → Uninstall HomePad…) runs this after quitting; it also works on its own, from Terminal:
#
#     bash uninstall.sh                 # uninstall /Applications/HomePad.app
#     bash uninstall.sh --dry-run       # only show what would be done
#
# Options: --dry-run, --notify (show a message when done), --wait PID (wait for HomePad to quit first), and the app's
# path if it isn't /Applications/HomePad.app. Asks for an administrator password only if the app or the installer's
# record belongs to the system (as after installing with HomePad.pkg).
set -u

ID="local.mike.HomePad"
DRY=0
NOTIFY=0
WAIT=""
APP=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --notify) NOTIFY=1 ;;
        --wait) WAIT="${2:-}"; shift ;;
        *) APP="$1" ;;
    esac
    shift
done
[ -z "$APP" ] && APP="/Applications/HomePad.app"

say() { echo "HomePad uninstall: $*"; }
run() { if [ "$DRY" = 1 ]; then echo "  would run: $*"; else "$@"; fi }

# 1. HomePad itself quits first (when run from its menu it is quitting already).
if [ -n "$WAIT" ]; then
    for _ in $(seq 1 100); do /bin/kill -0 "$WAIT" 2>/dev/null || break; /bin/sleep 0.1; done
fi
if /usr/bin/pgrep -x HomePad >/dev/null; then
    say "quitting HomePad"
    run /usr/bin/pkill -x HomePad
    [ "$DRY" = 1 ] || /bin/sleep 1
fi

# 2. The Dock back, if HomePad hid it (auto-hide with its very long delay).
DELAY=$(/usr/bin/defaults read com.apple.dock autohide-delay 2>/dev/null || echo 0)
if [ "${DELAY%%.*}" -ge 100 ] 2>/dev/null; then
    say "bringing the Dock back"
    run /usr/bin/defaults write com.apple.dock autohide -bool false
    run /usr/bin/defaults delete com.apple.dock autohide-delay
    run /usr/bin/killall Dock
fi

# 3. Permissions (Screen Recording, Accessibility, Full Disk Access, Finder control) back to "never asked".
say "taking back HomePad's permissions"
run /usr/bin/tccutil reset All "$ID"

# 4. Settings and categories, including those of HomePad's earlier names, and its caches.
say "erasing HomePad's settings"
for domain in "$ID" local.mike.SpotlightPlus local.mike.StartMenu; do
    if /usr/bin/defaults read "$domain" >/dev/null 2>&1; then run /usr/bin/defaults delete "$domain"; fi
done
for path in "$HOME/Library/Caches/$ID" "$HOME/Library/HTTPStorages/$ID" "$HOME/Library/Saved Application State/$ID.savedState"; do
    if [ -e "$path" ]; then run /bin/rm -rf "$path"; fi
done

# 5. The app to the Trash (it can be put back from there), and the installer's record. Both need an administrator
#    when the installer put them there; then they are done together, with one password prompt.
ADMIN=""
if [ -e "$APP" ]; then
    TRASH="$HOME/.Trash/HomePad.app"
    [ -e "$TRASH" ] && TRASH="$HOME/.Trash/HomePad $(/bin/date +%Y-%m-%d\ %H.%M.%S).app"
    say "moving $APP to the Trash"
    if [ "$DRY" = 1 ]; then
        echo "  would run: mv '$APP' '$TRASH' (as an administrator if needed)"
    elif ! /bin/mv "$APP" "$TRASH" 2>/dev/null; then
        ADMIN="/bin/mv '$APP' '$TRASH'"
    fi
else
    say "no app at $APP (already removed)"
fi
if /usr/sbin/pkgutil --pkg-info "$ID" >/dev/null 2>&1; then
    say "forgetting the installer's record"
    if [ "$DRY" = 1 ]; then echo "  would run: pkgutil --forget $ID (as an administrator)"
    else ADMIN="${ADMIN:+$ADMIN; }/usr/sbin/pkgutil --forget $ID"; fi
fi
if [ -n "$ADMIN" ]; then
    /usr/bin/osascript -e "do shell script \"$ADMIN\" with prompt \"HomePad needs your password to finish uninstalling.\" with administrator privileges" >/dev/null \
        || say "that step was cancelled; drag HomePad from Applications to the Trash yourself"
fi

say "done"
if [ "$NOTIFY" = 1 ] && [ "$DRY" = 0 ]; then
    /usr/bin/osascript -e 'display dialog "HomePad has been uninstalled. It is in the Trash, in case you want it back." buttons {"OK"} default button 1 with title "HomePad" with icon note' >/dev/null 2>&1
fi
exit 0
