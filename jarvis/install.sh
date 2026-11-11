#!/bin/bash
# Install JARVIS: venv + models, config with a random token, CLI, systemd user service.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HOME/.local/share/jarvis/venv"
CONF="$HOME/.config/jarvis/config.toml"

for c in claude ffmpeg mpv parec paplay; do
  command -v "$c" >/dev/null || { echo "falta '$c'"; exit 1; }
done
command -v qrencode >/dev/null || sudo apt-get install -y qrencode || true

echo "==> entorno Python ($VENV)"
[[ -x "$VENV/bin/python" ]] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$HERE/requirements.txt"
"$VENV/bin/pip" install -q --no-deps "openwakeword==0.6.0"

echo "==> modelos (hey jarvis + whisper)"
"$VENV/bin/python" -I -c 'import openwakeword.utils as u; u.download_models(["hey_jarvis"])'
WM=$(sed -nE 's/^whisper_model *= *"([^"]+)".*/\1/p' "$CONF" 2>/dev/null || true)
"$VENV/bin/python" -I -c "from faster_whisper import WhisperModel as W; W('${WM:-small}', device='cpu', compute_type='int8')" >/dev/null

echo "==> configuración"
if [[ ! -f "$CONF" ]]; then
  mkdir -p "$(dirname "$CONF")"
  sed "s/__TOKEN__/$(openssl rand -hex 24)/" "$HERE/config.example.toml" > "$CONF"
  chmod 600 "$CONF"
  echo "    creado $CONF"
fi

echo "==> CLI + servicio"
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
ln -sf "$HERE/bin/jarvis" "$HOME/.local/bin/jarvis"
ln -sf "$HERE/jarvis.service" "$HOME/.config/systemd/user/jarvis.service"
systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user restart jarvis   # started per X session from bspwm/start

cat <<MSG

JARVIS instalado.
  super + a          hablarle (otra vez para terminar / callarlo)
  super + shift + a  activar/desactivar "hey jarvis"
  jarvis url         URL y QR para el celular (requiere Tailscale, ver README)
MSG
