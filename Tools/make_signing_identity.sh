#!/bin/zsh
# Creates a local self-signed code-signing identity "GlobeSwitch Signing" in its own keychain, so the
# app's signature — and with it the Accessibility grant stored by macOS — stays the same across rebuilds.
# Run once: Tools/make_signing_identity.sh . macOS asks for the Mac password once (trusting the certificate).
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="GlobeSwitch Signing"
DIR=.signing
KC="$HOME/Library/Keychains/GlobeSwitch.keychain-db"
PW_FILE="$DIR/keychain-password"

mkdir -p "$DIR"; chmod 700 "$DIR"
if [[ -f "$KC" ]] && security find-identity -v -p codesigning "$KC" 2>/dev/null | grep -q "$NAME"; then
  echo "Подпись «$NAME» уже есть в $KC"; exit 0
fi
[[ -f "$PW_FILE" ]] || { openssl rand -hex 24 > "$PW_FILE"; chmod 600 "$PW_FILE"; }
PW=$(cat "$PW_FILE")

TMP=$(mktemp -d)
cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
O = Ivan
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" \
  -passout pass:p12 -name "$NAME" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

[[ -f "$KC" ]] || security create-keychain -p "$PW" "$KC"
security set-keychain-settings "$KC"                 # never auto-lock
security unlock-keychain -p "$PW" "$KC"
security import "$TMP/id.p12" -k "$KC" -P p12 -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PW" "$KC" >/dev/null
# codesign looks identities up through the user's keychain search list only.
if ! security list-keychains -d user | grep -q "GlobeSwitch.keychain-db"; then
  security list-keychains -d user -s $(security list-keychains -d user | tr -d ' "') "$KC"
fi
cp "$TMP/cert.pem" "$DIR/GlobeSwitch-signing.pem"
echo "Сейчас macOS спросит пароль: это доверие сертификату «$NAME» для подписи кода."
security add-trusted-cert -r trustRoot -p codeSign -k "$KC" "$TMP/cert.pem"
rm -rf "${TMP:?}"
echo "--- identities in $KC"; security find-identity -v -p codesigning "$KC"
