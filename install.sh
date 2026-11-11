#!/bin/bash
# Sets up a Serbian eID card (licna karta sa cipom) for web login on macOS:
# installs Firefox if missing, installs the open-source srb-id-pkcs11 module,
# and registers it in Firefox through a system-wide enterprise policy.
set -euo pipefail

MODULE_VERSION="v0.6.0"
SHA_ARM="34def9b1c138148e9d27d948baa9aedb34eeaf2e19bc808a0305bd20459eaa09"
SHA_X64="8c71d4696fd275582a4b8ba4c4678019cf490ddb10eb83956575228b20551e2e"
MODULE_NAME="Licna karta"
INSTALL_DIR="/Library/Application Support/srb-id-pkcs11"
MODULE_PATH="$INSTALL_DIR/libsrb-id-pkcs11.dylib"
POLICY_DOMAIN="/Library/Preferences/org.mozilla.firefox"
FIREFOX_APP="/Applications/Firefox.app"
FIREFOX_DMG_URL="https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mGreska: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Ova skripta radi samo na macOS-u."

case "$(uname -m)" in
  arm64)  ARCH="arm"; SHA="$SHA_ARM" ;;
  x86_64) ARCH="x64"; SHA="$SHA_X64" ;;
  *)      fail "Nepoznat procesor: $(uname -m)" ;;
esac

TMP="$(mktemp -d)"
trap 'hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

say "Podesavanje licne karte za prijavu na eUpravu i eFakturu"
echo "Skripta trazi lozinku ovog Mac-a jednom, za upis u sistemske foldere."
sudo -v || fail "Potrebna je lozinka administratora."

# 1. Firefox
if [ -d "$FIREFOX_APP" ]; then
  say "1/3 Firefox je vec instaliran."
else
  say "1/3 Preuzimam Firefox sa mozilla.org..."
  curl -fL --progress-bar -o "$TMP/firefox.dmg" "$FIREFOX_DMG_URL"
  mkdir "$TMP/mnt"
  hdiutil attach "$TMP/firefox.dmg" -nobrowse -readonly -mountpoint "$TMP/mnt" -quiet
  codesign --verify --deep --strict "$TMP/mnt/Firefox.app" \
    || fail "Potpis preuzetog Firefox-a nije ispravan. Instalacija je prekinuta."
  sudo ditto "$TMP/mnt/Firefox.app" "$FIREFOX_APP"
  hdiutil detach "$TMP/mnt" -quiet
  echo "Firefox je instaliran."
fi

# 2. PKCS#11 module, pinned version, verified by SHA-256
say "2/3 Preuzimam modul za licnu kartu ($MODULE_VERSION, $ARCH)..."
curl -fsSL -o "$TMP/module.dylib" \
  "https://github.com/ubavic/srb-id-pkcs11/releases/download/$MODULE_VERSION/libsrb-id-pkcs11.$ARCH.dylib"
GOT="$(shasum -a 256 "$TMP/module.dylib" | awk '{print $1}')"
[ "$GOT" = "$SHA" ] || fail "SHA-256 otisak modula se ne poklapa. Fajl nije instaliran."
sudo mkdir -p "$INSTALL_DIR"
sudo install -m 755 -o root -g wheel "$TMP/module.dylib" "$MODULE_PATH"
echo "Modul je u: $MODULE_PATH"

# 3. Firefox enterprise policy (merged with any existing policies)
say "3/3 Podesavam Firefox..."
PLIST="$TMP/policy.plist"
if ! sudo defaults export "$POLICY_DOMAIN" "$PLIST" 2>/dev/null; then
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict/></plist>\n' > "$PLIST"
fi
sudo chown "$(id -u)" "$PLIST"
plutil -replace EnterprisePoliciesEnabled -bool YES "$PLIST"
plutil -replace SecurityDevices -json "{\"Add\":{\"$MODULE_NAME\":\"$MODULE_PATH\"}}" "$PLIST"
sudo defaults import "$POLICY_DOMAIN" "$PLIST"

say "Gotovo."
cat <<EOF
Dalje:
  1. Zatvori Firefox potpuno (Cmd + Q) ako je bio otvoren, pa ga otvori ponovo.
  2. Ubaci licnu kartu u citac.
  3. Idi na https://efaktura.mfin.gov.rs/login i izaberi prijavu
     kvalifikovanim elektronskim sertifikatom.
  4. Izaberi sertifikat za autentifikaciju i unesi PIN licne karte.

Provera: u Firefox-u otvori chrome://pippki/content/device_manager.xhtml.
U levoj listi treba da pise "$MODULE_NAME".
EOF
