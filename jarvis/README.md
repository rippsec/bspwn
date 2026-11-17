# J.A.R.V.I.S.

Asistente de voz para esta máquina: le hablas (en la PC o desde el celular), te
contesta con voz y puede **ejecutar código, controlar el escritorio y planear
proyectos**. El cerebro es Claude Code (`claude -p`) con una sesión persistente,
así que recuerda la conversación y tiene acceso a la terminal.

```
 micrófono PC ─┐                                   ┌─ voz en la PC (mpv)
 "hey jarvis"  ├─ faster-whisper ─ claude -p ─ edge-tts ─┤
 celular (PWA) ┘   (GPU, español)   (Claude Code)        └─ voz en el celular
```

## Instalar

```bash
~/.bspwn/jarvis/install.sh
```

Esto crea el venv en `~/.local/share/jarvis/venv`, descarga los modelos, genera
`~/.config/jarvis/config.toml` (con un token aleatorio), enlaza el comando
`jarvis` y el servicio de usuario `jarvis.service`. `bspwm/start` lo arranca en
cada sesión de X.

## Uso en la PC

| Atajo | Acción |
|---|---|
| `super + a` | hablarle · otra vez = terminar de hablar · mientras habla = callarlo |
| `super + shift + a` | activar/desactivar "hey Jarvis" (micrófono siempre abierto) |
| `super + ctrl + a` | cancelar lo que esté haciendo |
| polybar 󰚩 | clic = hablar · clic derecho = wake word · clic medio = cancelar |

```bash
jarvis ask "prepara un plan para una app de notas en Flask"
jarvis say "Hola"        # que diga algo sin pensar
jarvis reset             # nueva conversación
jarvis logs              # ver qué está pasando
```

Lo largo (planes, código) lo guarda en `~/jarvis/<proyecto>/` y te lo resume en voz.

## Acceso desde el celular

El micrófono del navegador solo funciona con HTTPS, así que se usa Tailscale
(VPN privada, gratis). El daemon solo escucha en `127.0.0.1`, y Tailscale lo
publica únicamente dentro de tu red privada.

1. En la PC:
   ```bash
   sudo systemctl enable --now tailscaled
   sudo tailscale up            # abre el login en el navegador
   sudo tailscale set --operator=$USER
   tailscale serve --bg 8765    # https://<tu-pc>.<tailnet>.ts.net -> jarvis
   ```
   (Si `serve` pide activar HTTPS, sigue el enlace que imprime.)
2. En el celular: instala la app Tailscale e inicia sesión con la misma cuenta.
3. `jarvis url` muestra la URL con el token y un QR. Ábrelo en el celular y usa
   "Agregar a pantalla de inicio" para tenerlo como app.

En la app: toca el reactor para hablar y otra vez para enviar, o escribe.
"voz en" elige dónde suena la respuesta (celular, PC, ambos, mudo). La fila
de botones tiene la captura de la pantalla de la PC, la música, el volumen,
el bloqueo y "Mic PC", que hace que la PC te escuche.

## Archivos (celular ↔ PC)

En la app:

- **📎 Subir**: manda archivos del celular a la PC. Caen en `<projects_dir>/inbox`
  y Jarvis los puede usar: "lee el PDF que subí y resúmelo", "convierte esa foto".
- **📁 Archivos**: explora las carpetas de la PC. Toca un archivo para descargarlo
  al celular, una carpeta para entrar, ⬇ para bajar una carpeta completa como zip,
  🗑 para borrar, ＋ para crear carpeta, y "📎 Subir aquí" para subir a la carpeta
  que estás viendo.
- Cuando Jarvis crea algo (un script, un informe), aparece en el chat con un
  enlace para descargarlo directo al celular.

Qué carpetas se pueden ver se controla con `file_roots` en el config (por defecto
`["~"]`, toda tu carpeta personal). Las rutas se confinan a esas raíces: no se
puede salir con `..` ni con enlaces simbólicos. **Quien tenga el token puede
leer y escribir todo lo que esté bajo `file_roots`**, así que mantén esa lista
corta si quieres limitar el alcance.

## Auditoría

Cada acción con permisos (archivos, comandos de control, lo que le pides al
cerebro) se registra en `~/.local/share/jarvis/audit.log` (JSON por línea, con
hora e IP de origen). Revísalo con:

```bash
jarvis audit           # últimas 40 acciones
jarvis audit 200
```

## Varias máquinas

Cada equipo corre su propio `jarvisd` con su token. La app guarda una lista de
máquinas y el selector del encabezado elige a cuál le hablas; todo (chat, voz,
archivos, pantalla) va a la máquina activa.

1. Instala Jarvis en el otro equipo y exponlo con Tailscale igual que este.
   Ponle un nombre claro con `machine_name` en su config.
2. En la app, abre el selector de máquina (arriba) → **➕ Agregar…** y pega la
   URL que da `jarvis url` en ese equipo (incluye su token).
3. Cambia entre equipos con el mismo selector. Cada uno mantiene su propia
   conversación y su sesión de Claude.

Esto funciona porque el agente acepta el token por cabecera o por `?t=` y
responde con CORS, así que la app cargada desde una máquina puede hablarle a
otra dentro de tu red de Tailscale. Es la base para administrar varios
servidores desde un mismo panel.

## Configuración

`~/.config/jarvis/config.toml` (reinicia con `jarvis restart`):

- `model`: `sonnet` (rápido, por defecto), `opus` (más listo) o `haiku`. También se elige en la app.
- `permission_mode`: con `bypassPermissions`, Jarvis ejecuta comandos sin
  preguntar. La personalidad le indica pedir confirmación antes de algo
  destructivo, pero es una instrucción, no un candado. Usa `acceptEdits` si
  prefieres que no corra comandos.
- `whisper_model`: `small` · `medium` · `large-v3-turbo` (mejor precisión, más VRAM).
- `voice`: cualquier voz de `edge-tts --list-voices` (p. ej. `es-ES-AlvaroNeural`).
- `user_title`: cómo quieres que te llame Jarvis.
- `machine_name`: nombre de este equipo en el selector de máquina (por defecto el hostname).
- `wake_word = true` para que arranque escuchando "hey Jarvis".

La personalidad está en `persona.md`.

## Seguridad

- Cada petición necesita el token (cookie o `Authorization: Bearer`). No compartas la URL de `jarvis url`.
- No expongas el puerto a internet (`tailscale funnel`, `host = "0.0.0.0"` en una red pública): quien tenga el token controla la PC.
- Para cambiar el token, edítalo en el config y reinicia.

## Estructura del proyecto

- `jarvisd.py`: el daemon (STT, wake word, Claude, TTS, API y SSE).
- `web/`: la PWA del celular.
- `bin/jarvis`: el CLI, que también usan sxhkd y polybar.
- `persona.md`: el system prompt de Jarvis.
- Estado en ejecución: `$XDG_RUNTIME_DIR/jarvis/`. Historial y sesión: `~/.local/share/jarvis/`.
