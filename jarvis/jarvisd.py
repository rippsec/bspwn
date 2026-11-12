#!/usr/bin/env python3
"""
JARVIS daemon — voice + phone front-end for Claude Code.

  ears   : faster-whisper (GPU) for speech-to-text, openWakeWord "hey jarvis"
  brain  : `claude -p` (Claude Code) with a persistent session -> can run code,
           control the desktop, plan projects
  mouth  : edge-tts neural voice, played with mpv on the PC or in the phone
  remote : aiohttp server + PWA (expose with `tailscale serve`), token protected

Everything that happens (PC voice, phone voice, phone text) is broadcast over
SSE, so the phone sees the same conversation as the desktop.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import time
import tomllib
import uuid
from pathlib import Path

import numpy as np
from aiohttp import web

HERE = Path(__file__).resolve().parent
CONFIG_PATH = Path(os.environ.get("JARVIS_CONFIG", Path.home() / ".config/jarvis/config.toml"))
DATA_DIR = Path.home() / ".local/share/jarvis"
RUN_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "jarvis"
AUDIO_DIR = RUN_DIR / "audio"
STATE_FILE = RUN_DIR / "state"          # read by the polybar module
SESSION_FILE = DATA_DIR / "session.json"
HISTORY_FILE = DATA_DIR / "history.json"
SR = 16000                              # mic / whisper sample rate
CHUNK = 1280                            # 80 ms, what openWakeWord expects

log = logging.getLogger("jarvis")

DEFAULTS = {
    "host": "127.0.0.1",
    "port": 8765,
    "token": "",
    "model": "sonnet",
    "permission_mode": "bypassPermissions",
    "workdir": str(Path.home()),
    "projects_dir": str(Path.home() / "jarvis"),
    "user_title": "",
    "language": "es",
    "whisper_model": "small",
    "whisper_device": "cuda",
    "voice": "es-MX-JorgeNeural",
    "voice_rate": "+8%",
    "wake_word": True,
    "wake_threshold": 0.5,
    "silence_seconds": 1.2,
    "max_record_seconds": 30,
    "speak_max_chars": 700,
    # File manager: directories the phone may browse/upload/download within.
    # Keep this tight — anyone with the token can read/write anything under these.
    "file_roots": ["~"],
}


def load_config() -> dict:
    cfg = dict(DEFAULTS)
    if CONFIG_PATH.exists():
        cfg.update(tomllib.loads(CONFIG_PATH.read_text()))
    for k in ("workdir", "projects_dir"):
        cfg[k] = os.path.expanduser(cfg[k])
    if not cfg["token"]:
        sys.exit(f"jarvis: set `token` in {CONFIG_PATH} (run jarvis/install.sh)")
    return cfg


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def notify(title: str, body: str = "", *, replace: int = 7700, urgency: str = "low"):
    exe = shutil.which("dunstify") or shutil.which("notify-send")
    if not exe:
        return
    args = [exe, "-a", "Jarvis", "-u", urgency, "-r", str(replace), title, body[:400]]
    subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def chime(kind: str):
    """Short synthesized beeps so we don't depend on sound themes."""
    freqs = {"start": (880, 1320), "stop": (1320, 880), "error": (300, 220)}[kind]
    t = np.linspace(0, 0.09, int(SR * 0.09), False)
    tone = np.concatenate([np.sin(2 * np.pi * f * t) for f in freqs])
    env = np.minimum(1, np.minimum(np.arange(len(tone)), len(tone) - np.arange(len(tone))) / 400)
    pcm = (tone * env * 0.25 * 32767).astype(np.int16).tobytes()
    p = subprocess.Popen(["paplay", "--raw", f"--rate={SR}", "--channels=1", "--format=s16le"],
                         stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        p.stdin.write(pcm)
        p.stdin.close()
    except BrokenPipeError:
        pass


def speakable(text: str, limit: int) -> str:
    """Turn a markdown answer into something sensible to say out loud."""
    t = re.sub(r"```.*?```", " (te dejé el código en pantalla) ", text, flags=re.S)
    t = re.sub(r"`([^`]*)`", r"\1", t)
    t = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"https?://\S+", "el enlace", t)
    t = re.sub(r"^\s*\|.*\|\s*$", "", t, flags=re.M)          # tables
    t = re.sub(r"^\s*#+\s*", "", t, flags=re.M)
    t = re.sub(r"^\s*[-*+]\s+", "", t, flags=re.M)
    t = re.sub(r"[*_~>#]", "", t)
    t = re.sub(r"\s+", " ", t).strip()
    if len(t) > limit:
        cut = t[:limit]
        end = max(cut.rfind(". "), cut.rfind("? "), cut.rfind("! "))
        t = (cut[: end + 1] if end > limit // 3 else cut) + " El resto está en pantalla."
    return t


AUDIT_FILE = DATA_DIR / "audit.log"


def audit(action: str, *, who: str = "-", **detail):
    """Append-only JSONL record of every privileged action (file op, command,
    control). This is a self-hosted admin tool for the owner's own machines;
    the audit trail is what makes that accountable."""
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "action": action, "who": who, **detail}
    try:
        with AUDIT_FILE.open("a") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except OSError as e:
        log.warning("audit write failed: %s", e)
    log.info("audit %s %s %s", action, who, {k: v for k, v in detail.items() if k != "preview"})


class FileAccess:
    """Confines every file operation to a set of allowed root directories.
    Paths are resolved (symlinks included) and must stay inside a root, so the
    phone cannot walk out via `..` or a symlink."""

    def __init__(self, roots: list[str]):
        self.roots: list[Path] = []
        for r in roots:
            p = Path(os.path.expanduser(r)).resolve()
            if p.is_dir():
                self.roots.append(p)
        if not self.roots:
            self.roots = [Path.home()]

    def resolve(self, raw: str, *, must_exist: bool = True) -> Path:
        raw = (raw or "").strip() or str(self.roots[0])
        p = Path(os.path.expanduser(raw))
        if not p.is_absolute():
            p = self.roots[0] / p
        target = p.resolve()
        if not any(target == root or root in target.parents for root in self.roots):
            raise PermissionError(f"fuera de las carpetas permitidas: {raw}")
        if must_exist and not target.exists():
            raise FileNotFoundError(raw)
        return target

    def listing(self, raw: str) -> dict:
        d = self.resolve(raw)
        if not d.is_dir():
            raise NotADirectoryError(raw)
        entries = []
        for e in sorted(d.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
            try:
                st = e.stat()
                entries.append({"name": e.name, "dir": e.is_dir(),
                                "size": st.st_size if not e.is_dir() else None,
                                "mtime": int(st.st_mtime)})
            except OSError:
                continue
        at_root = any(d == root for root in self.roots)
        return {"path": str(d), "parent": None if at_root else str(d.parent),
                "roots": [str(r) for r in self.roots], "entries": entries}


async def decode_to_pcm(data: bytes) -> np.ndarray:
    """Any browser audio blob (webm/opus, mp4/aac, ogg) -> float32 mono 16 kHz."""
    p = await asyncio.create_subprocess_exec(
        "ffmpeg", "-loglevel", "error", "-i", "pipe:0", "-f", "s16le", "-ac", "1", "-ar", str(SR), "pipe:1",
        stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    out, err = await p.communicate(data)
    if p.returncode != 0:
        raise RuntimeError(f"ffmpeg: {err.decode()[:200]}")
    return np.frombuffer(out, np.int16).astype(np.float32) / 32768


def cuda_lib_path() -> str:
    """cuBLAS/cuDNN come from pip wheels inside the venv."""
    paths = []
    for mod in ("nvidia.cublas.lib", "nvidia.cudnn.lib"):
        try:
            m = __import__(mod, fromlist=["_"])
            paths.append(list(m.__path__)[0])
        except Exception:
            pass
    return ":".join(paths)


# ---------------------------------------------------------------------------
# Jarvis
# ---------------------------------------------------------------------------

class Jarvis:
    def __init__(self, cfg: dict):
        self.cfg = cfg
        self.state = "idle"
        self.clients: set[asyncio.Queue] = set()
        self.history: list[dict] = self._load(HISTORY_FILE, [])[-80:]
        self.session_id: str | None = self._load(SESSION_FILE, {}).get("id")
        self.brain_lock = asyncio.Lock()
        self.claude_proc: asyncio.subprocess.Process | None = None
        self.cancelled = False
        self.player: asyncio.subprocess.Process | None = None
        self.whisper = None
        self.wake_enabled = bool(cfg["wake_word"])
        self.mic_task: asyncio.Task | None = None
        self.record_request: asyncio.Event = asyncio.Event()
        self.record_stop: asyncio.Event = asyncio.Event()
        self.files = FileAccess(cfg["file_roots"])
        self.inbox = Path(cfg["projects_dir"]) / "inbox"
        self.persona = (HERE / "persona.md").read_text().format(
            projects_dir=cfg["projects_dir"],
            title=(f'Dirígete al usuario como "{cfg["user_title"]}". ' if cfg["user_title"] else ""),
        )
        for d in (RUN_DIR, AUDIO_DIR, DATA_DIR, Path(cfg["projects_dir"]), self.inbox):
            d.mkdir(parents=True, exist_ok=True)
        self.set_state("idle")

    # -- persistence ---------------------------------------------------------
    @staticmethod
    def _load(path: Path, default):
        try:
            return json.loads(path.read_text())
        except Exception:
            return default

    def _save(self):
        HISTORY_FILE.write_text(json.dumps(self.history[-80:], ensure_ascii=False))
        SESSION_FILE.write_text(json.dumps({"id": self.session_id}))

    # -- events ----------------------------------------------------------------
    def emit(self, kind: str, **data):
        ev = {"type": kind, "ts": time.time(), **data}
        if kind in ("user", "assistant", "tool", "error"):
            self.history.append(ev)
        for q in list(self.clients):
            q.put_nowait(ev)

    def set_state(self, state: str):
        self.state = state
        STATE_FILE.write_text(f"{state} {'wake' if self.wake_enabled else 'nowake'}\n")
        self.emit("state", state=state, wake=self.wake_enabled)

    # -- speech to text --------------------------------------------------------
    async def load_whisper(self):
        from faster_whisper import WhisperModel

        def _load():
            dev = self.cfg["whisper_device"]
            try:
                return WhisperModel(self.cfg["whisper_model"], device=dev,
                                    compute_type="int8_float16" if dev == "cuda" else "int8")
            except Exception as e:
                log.warning("whisper on %s failed (%s), using CPU", dev, e)
                return WhisperModel(self.cfg["whisper_model"], device="cpu", compute_type="int8")

        self.whisper = await asyncio.to_thread(_load)
        log.info("whisper ready")

    async def transcribe(self, audio: np.ndarray) -> str:
        while self.whisper is None:
            await asyncio.sleep(0.2)

        def _run():
            segs, _ = self.whisper.transcribe(
                audio, language=self.cfg["language"], beam_size=3, vad_filter=True,
                initial_prompt="Jarvis, ejecuta, abre, proyecto, código, terminal.")
            return " ".join(s.text.strip() for s in segs).strip()

        return await asyncio.to_thread(_run)

    # -- text to speech --------------------------------------------------------
    async def tts(self, text: str) -> Path | None:
        import edge_tts
        text = speakable(text, self.cfg["speak_max_chars"])
        if not text:
            return None
        path = AUDIO_DIR / f"{uuid.uuid4().hex}.mp3"
        try:
            await edge_tts.Communicate(text, self.cfg["voice"], rate=self.cfg["voice_rate"]).save(str(path))
        except Exception as e:
            log.warning("tts failed: %s", e)
            return None
        for old in sorted(AUDIO_DIR.glob("*.mp3"), key=lambda p: p.stat().st_mtime)[:-30]:
            old.unlink(missing_ok=True)
        return path

    async def play_local(self, path: Path):
        self.stop_playback()
        self.set_state("speaking")
        self.player = await asyncio.create_subprocess_exec(
            "mpv", "--no-video", "--really-quiet", str(path),
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
        await self.player.wait()
        self.player = None
        if self.state == "speaking":
            self.set_state("idle")

    def stop_playback(self):
        if self.player and self.player.returncode is None:
            self.player.terminate()
        self.emit("stop_audio")

    # -- brain (Claude Code) ---------------------------------------------------
    async def ask(self, text: str, *, source: str, speak: str, client: str | None = None,
                  model: str | None = None):
        """Run one turn through Claude Code. speak: pc | phone | both | none"""
        if self.brain_lock.locked():
            self.emit("error", text="Sigo trabajando en lo anterior. Usa «detener» si quieres cancelarlo.")
            return
        async with self.brain_lock:
            self.emit("user", text=text, source=source)
            self.set_state("thinking")
            notify("🎙  " + text, "pensando…")
            final = await self._run_claude(text, model or self.cfg["model"])
            self._save()
            if final is None:
                self.set_state("idle")
                return
            notify("Jarvis", final, replace=7701, urgency="normal")
            audio = await self.tts(final) if speak != "none" else None
            if audio:
                if speak in ("phone", "both"):
                    self.emit("audio", url=f"/audio/{audio.name}", client=client)
                if speak in ("pc", "both"):
                    asyncio.create_task(self.play_local(audio))
                    return
            self.set_state("idle")

    async def _run_claude(self, text: str, model: str) -> str | None:
        cmd = [shutil.which("claude") or str(Path.home() / ".local/bin/claude"), "-p",
               "--output-format", "stream-json", "--verbose",
               "--model", model,
               "--permission-mode", self.cfg["permission_mode"],
               "--append-system-prompt", self.persona]
        if self.session_id:
            cmd += ["--resume", self.session_id]
        log.info("claude <- %s", text)
        self.claude_proc = await asyncio.create_subprocess_exec(
            *cmd, cwd=self.cfg["workdir"], stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, limit=16 * 1024 * 1024)
        self.claude_proc.stdin.write(text.encode())
        self.claude_proc.stdin.close()
        final, texts = None, []
        async for raw in self.claude_proc.stdout:
            try:
                ev = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if ev.get("session_id"):
                self.session_id = ev["session_id"]
            if ev.get("type") == "assistant":
                for block in ev["message"].get("content", []):
                    if block.get("type") == "text" and block["text"].strip():
                        texts.append(block["text"])
                        self.emit("partial", text=block["text"])
                    elif block.get("type") == "tool_use":
                        self.emit("tool", name=block["name"], detail=self._tool_detail(block))
            elif ev.get("type") == "result" or "result" in ev:
                final = ev.get("result") or (texts[-1] if texts else "")
                if ev.get("is_error"):
                    self.emit("error", text=final or "Claude devolvió un error.")
                    final = None
        err = (await self.claude_proc.stderr.read()).decode()
        rc = await self.claude_proc.wait()
        self.claude_proc = None
        if self.cancelled:                        # /api/stop
            self.cancelled = False
            self.emit("error", text="Cancelado.")
            return None
        if final is None and rc != 0:
            if self.session_id and "session" in err.lower():
                self.session_id = None            # stale session -> start fresh next time
            self.emit("error", text=f"Claude falló ({rc}): {err.strip()[-300:]}")
            return None
        if final:
            self.emit("assistant", text=final)
        return final

    @staticmethod
    def _tool_detail(block: dict) -> str:
        i = block.get("input", {})
        for k in ("description", "command", "file_path", "pattern", "url", "query", "prompt"):
            if i.get(k):
                return str(i[k])[:160]
        return ""

    def cancel(self):
        if self.claude_proc and self.claude_proc.returncode is None:
            self.cancelled = True
            self.claude_proc.send_signal(signal.SIGINT)
            asyncio.get_running_loop().call_later(2, lambda p=self.claude_proc: p and p.returncode is None and p.kill())
        self.record_stop.set()
        self.stop_playback()

    def reset(self):
        self.session_id = None
        self.history.clear()
        self._save()
        self.emit("reset")

    # -- PC microphone: wake word + push-to-talk -------------------------------
    def ensure_mic(self):
        if self.mic_task is None or self.mic_task.done():
            self.mic_task = asyncio.create_task(self._mic_loop())

    def toggle_listen(self):
        """Hotkey: idle->listen, listening->finish early, speaking->shut up."""
        if self.state == "listening":
            self.record_stop.set()
        elif self.state == "speaking":
            self.stop_playback()
            self.set_state("idle")
        elif self.state == "idle":
            self.record_request.set()
            self.ensure_mic()
        else:
            notify("Jarvis", "Sigo pensando… (super+shift+a para cancelar)")

    def set_wake(self, on: bool):
        self.wake_enabled = on
        self.set_state(self.state)
        if on:
            self.ensure_mic()
        notify("Jarvis", "Escuchando «hey Jarvis»" if on else "Wake word desactivado (micrófono cerrado)")

    async def _mic_loop(self):
        """Owns the mic while wake word is on or a recording was requested.
        The mic is closed whenever neither is needed."""
        oww = vad = None
        if self.wake_enabled:
            try:
                from openwakeword.model import Model
                from openwakeword.vad import VAD
                oww = Model(wakeword_models=["hey_jarvis"], inference_framework="onnx")
                vad = VAD()
            except Exception as e:
                log.error("openwakeword unavailable: %s", e)
        if vad is None:
            try:
                from openwakeword.vad import VAD
                vad = VAD()
            except Exception:
                pass
        proc = await asyncio.create_subprocess_exec(
            "parec", "--raw", f"--rate={SR}", "--channels=1", "--format=s16le", "--latency-msec=40",
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        log.info("mic open")
        try:
            while self.wake_enabled or self.record_request.is_set():
                if self.record_request.is_set():
                    self.record_request.clear()
                    await self._record_command(proc, vad)
                    if oww:
                        oww.reset()
                    continue
                try:
                    data = await asyncio.wait_for(proc.stdout.readexactly(CHUNK * 2), 1)
                except asyncio.TimeoutError:
                    continue
                if oww is None or self.state != "idle":
                    continue                       # don't trigger on our own voice
                score = oww.predict(np.frombuffer(data, np.int16)).get("hey_jarvis", 0)
                if score >= self.cfg["wake_threshold"]:
                    log.info("wake word (%.2f)", score)
                    oww.reset()
                    self.record_request.set()
        except asyncio.IncompleteReadError:
            log.error("mic stream ended")
        finally:
            proc.kill()
            log.info("mic closed")

    async def _record_command(self, proc, vad):
        self.record_stop.clear()
        self.set_state("listening")
        chime("start")
        notify("🎙  Escuchando…", "habla ahora · super+a para terminar")
        # drop buffered audio (includes the chime / the wake word itself)
        try:
            while True:
                await asyncio.wait_for(proc.stdout.read(65536), 0.05)
        except asyncio.TimeoutError:
            pass
        frames, heard, quiet, start = [], False, 0.0, time.monotonic()
        noise = None
        while not self.record_stop.is_set():
            elapsed = time.monotonic() - start
            if elapsed > self.cfg["max_record_seconds"] or (not heard and elapsed > 7):
                break
            try:
                data = await asyncio.wait_for(proc.stdout.readexactly(CHUNK * 2), 1)
            except asyncio.TimeoutError:
                continue
            pcm = np.frombuffer(data, np.int16)
            frames.append(pcm)
            if vad is not None:
                speech = vad.predict(pcm, frame_size=640) > 0.5
            else:                                  # energy fallback
                rms = float(np.sqrt(np.mean(pcm.astype(np.float32) ** 2)))
                noise = rms if noise is None else noise
                speech = rms > max(400, noise * 3)
                if not speech:
                    noise = 0.9 * noise + 0.1 * rms
            if speech:
                heard, quiet = True, 0.0
            elif heard:
                quiet += CHUNK / SR
                if quiet >= self.cfg["silence_seconds"]:
                    break
        chime("stop")
        if not heard and not self.record_stop.is_set():
            notify("Jarvis", "No escuché nada.")
            self.set_state("idle")
            return
        self.set_state("thinking")
        audio = np.concatenate(frames).astype(np.float32) / 32768 if frames else np.zeros(0, np.float32)
        text = await self.transcribe(audio) if len(audio) > SR // 4 else ""
        if not text:
            notify("Jarvis", "No te entendí.")
            self.set_state("idle")
            return
        asyncio.create_task(self.ask(text, source="pc", speak="pc"))


# ---------------------------------------------------------------------------
# HTTP API
# ---------------------------------------------------------------------------

QUICK_ACTIONS = {
    "screenshot": None,  # handled separately (returns an image)
    "lock": ["xlock"],
    "vol_up": ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"],
    "vol_down": ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"],
    "mute": ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"],
    "play_pause": ["playerctl", "play-pause"],
    "next": ["playerctl", "next"],
    "prev": ["playerctl", "previous"],
}


def make_app(j: Jarvis) -> web.Application:
    token = j.cfg["token"]

    @web.middleware
    async def auth(request: web.Request, handler):
        if request.path in ("/manifest.webmanifest", "/icon.svg", "/sw.js"):
            return await handler(request)
        q = request.query.get("t")
        given = q or request.cookies.get("jarvis") or request.headers.get("Authorization", "").removeprefix("Bearer ")
        if not secrets.compare_digest(given or "", token):
            return web.Response(status=401, text="401 — abre la URL con ?t=<token> (jarvis url)")
        if q and request.method == "GET" and request.path == "/":
            resp = web.HTTPFound("/")
            resp.set_cookie("jarvis", token, max_age=3600 * 24 * 365, httponly=True, samesite="Strict",
                            secure=request.headers.get("X-Forwarded-Proto") == "https" or request.secure)
            raise resp
        return await handler(request)

    async def index(_):
        return web.FileResponse(HERE / "web/index.html", headers={"Cache-Control": "no-cache"})

    async def events(request):
        resp = web.StreamResponse(headers={"Content-Type": "text/event-stream", "Cache-Control": "no-cache",
                                           "X-Accel-Buffering": "no"})
        await resp.prepare(request)
        q: asyncio.Queue = asyncio.Queue()
        j.clients.add(q)
        try:
            hello = {"type": "hello", "state": j.state, "wake": j.wake_enabled, "history": j.history[-60:],
                     "model": j.cfg["model"]}
            await resp.write(f"data: {json.dumps(hello, ensure_ascii=False)}\n\n".encode())
            while True:
                try:
                    ev = await asyncio.wait_for(q.get(), 20)
                    if ev is None:                 # shutting down
                        break
                    await resp.write(f"data: {json.dumps(ev, ensure_ascii=False)}\n\n".encode())
                except asyncio.TimeoutError:
                    await resp.write(b": ping\n\n")
        except (ConnectionResetError, asyncio.CancelledError):
            pass
        finally:
            j.clients.discard(q)
        return resp

    async def chat(request):
        body = await request.json()
        text = (body.get("text") or "").strip()
        if not text:
            raise web.HTTPBadRequest(text="empty")
        audit("ask", who=request.remote, source=body.get("source", "phone"), preview=text[:200])
        asyncio.create_task(j.ask(text, source=body.get("source", "phone"), speak=body.get("speak", "phone"),
                                  client=body.get("client"), model=body.get("model")))
        return web.json_response({"ok": True})

    async def voice(request):
        post = await request.post()
        f = post.get("audio")
        if f is None:
            raise web.HTTPBadRequest(text="no audio")
        j.set_state("thinking")
        try:
            text = await j.transcribe(await decode_to_pcm(f.file.read()))
        except Exception as e:
            j.set_state("idle")
            j.emit("error", text=f"No pude procesar el audio: {e}")
            return web.json_response({"ok": False})
        j.set_state("idle")
        if not text:
            j.emit("error", text="No te entendí.")
            return web.json_response({"ok": False})
        audit("ask", who=request.remote, source="voice", preview=text[:200])
        asyncio.create_task(j.ask(text, source="phone", speak=post.get("speak", "phone"),
                                  client=post.get("client"), model=post.get("model")))
        return web.json_response({"ok": True, "text": text})

    async def control(request):
        action = request.match_info["action"]
        body = await request.json() if request.can_read_body else {}
        audit("control", who=request.remote, cmd=action)
        if action == "listen":
            j.toggle_listen()
        elif action == "stop":
            j.cancel()
        elif action == "reset":
            j.reset()
        elif action == "wake":
            j.set_wake(body.get("on", not j.wake_enabled))
        elif action == "say":                      # make Jarvis talk without the brain
            path = await j.tts(body.get("text", ""))
            if path:
                asyncio.create_task(j.play_local(path))
        elif action in QUICK_ACTIONS and QUICK_ACTIONS[action]:
            subprocess.Popen(QUICK_ACTIONS[action], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            raise web.HTTPNotFound()
        return web.json_response({"ok": True, "state": j.state, "wake": j.wake_enabled})

    async def screenshot(_):
        p = await asyncio.create_subprocess_exec("maim", "-u", "-f", "jpg", "-m", "7",
                                                 stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        out, err = await p.communicate()
        if p.returncode:
            raise web.HTTPInternalServerError(text=err.decode())
        return web.Response(body=out, content_type="image/jpeg", headers={"Cache-Control": "no-store"})

    async def status(_):
        return web.json_response({"state": j.state, "wake": j.wake_enabled, "session": j.session_id,
                                  "roots": [str(r) for r in j.files.roots]})

    # -- file manager ---------------------------------------------------------
    def fail(e: Exception) -> web.Response:
        code = {PermissionError: 403, FileNotFoundError: 404, NotADirectoryError: 400,
                IsADirectoryError: 400, FileExistsError: 409}.get(type(e), 400)
        return web.json_response({"ok": False, "error": str(e)}, status=code)

    async def files_list(request):
        try:
            return web.json_response(j.files.listing(request.query.get("path", "")))
        except Exception as e:
            return fail(e)

    async def files_download(request):
        try:
            p = j.files.resolve(request.query.get("path", ""))
            if p.is_dir():
                raise IsADirectoryError("es una carpeta")
        except Exception as e:
            return fail(e)
        audit("download", who=request.remote, path=str(p), size=p.stat().st_size)
        j.emit("file", op="download", path=str(p), name=p.name)
        return web.FileResponse(p, headers={
            "Content-Disposition": f'attachment; filename="{p.name}"', "Cache-Control": "no-store"})

    async def files_upload(request):
        reader = await request.multipart()
        dest_raw = ""
        saved = []
        async for part in reader:
            if part.name == "path":
                dest_raw = (await part.text()).strip()
                continue
            if part.name != "file" or not part.filename:
                continue
            try:
                folder = j.files.resolve(dest_raw) if dest_raw else j.inbox
            except Exception as e:
                return fail(e)
            folder.mkdir(parents=True, exist_ok=True)
            name = Path(part.filename).name or "archivo"
            target = folder / name
            n = 1
            while target.exists():                 # never overwrite silently
                target = folder / f"{Path(name).stem}_{n}{Path(name).suffix}"
                n += 1
            size = 0
            with target.open("wb") as fh:
                while chunk := await part.read_chunk(1 << 16):
                    size += len(chunk)
                    fh.write(chunk)
            saved.append({"path": str(target), "name": target.name, "size": size})
            audit("upload", who=request.remote, path=str(target), size=size)
            j.emit("file", op="upload", path=str(target), name=target.name, size=size)
        if not saved:
            return web.json_response({"ok": False, "error": "sin archivos"}, status=400)
        return web.json_response({"ok": True, "saved": saved})

    async def files_op(request):
        action = request.match_info["action"]
        body = await request.json()
        try:
            if action == "mkdir":
                parent = j.files.resolve(body.get("path", ""))
                d = (parent / Path(body["name"]).name)
                d.mkdir(parents=False, exist_ok=False)
                audit("mkdir", who=request.remote, path=str(d))
                return web.json_response({"ok": True, "path": str(d)})
            if action == "delete":
                p = j.files.resolve(body.get("path", ""))
                if any(p == root for root in j.files.roots):
                    raise PermissionError("no se puede borrar una carpeta raíz")
                if p.is_dir():
                    shutil.rmtree(p)
                else:
                    p.unlink()
                audit("delete", who=request.remote, path=str(p))
                j.emit("file", op="delete", path=str(p), name=p.name)
                return web.json_response({"ok": True})
        except Exception as e:
            return fail(e)
        raise web.HTTPNotFound()

    app = web.Application(middlewares=[auth], client_max_size=4 * 1024 ** 3)
    app.add_routes([
        web.get("/", index),
        web.get("/api/events", events),
        web.get("/api/status", status),
        web.post("/api/chat", chat),
        web.post("/api/voice", voice),
        web.get("/api/files", files_list),
        web.get("/api/download", files_download),
        web.post("/api/upload", files_upload),
        web.post("/api/files/{action}", files_op),
        web.post("/api/{action}", control),
        web.get("/api/screenshot", screenshot),
        web.static("/audio", AUDIO_DIR),
        web.get("/manifest.webmanifest", lambda r: web.FileResponse(HERE / "web/manifest.webmanifest")),
        web.get("/icon.svg", lambda r: web.FileResponse(HERE / "web/icon.svg")),
        web.get("/sw.js", lambda r: web.FileResponse(HERE / "web/sw.js")),
    ])

    async def on_start(_):
        asyncio.create_task(j.load_whisper())
        if j.wake_enabled:
            j.ensure_mic()

    async def on_shutdown(_):
        for q in list(j.clients):
            q.put_nowait(None)
        j.cancel()

    app.on_startup.append(on_start)
    app.on_shutdown.append(on_shutdown)
    return app


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    cfg = load_config()
    if cfg["whisper_device"] == "cuda" and "LD_LIBRARY_PATH_SET" not in os.environ:
        # ctranslate2 dlopen()s cuBLAS/cuDNN: the path must be set before the process starts
        os.environ["LD_LIBRARY_PATH"] = cuda_lib_path() + ":" + os.environ.get("LD_LIBRARY_PATH", "")
        os.environ["LD_LIBRARY_PATH_SET"] = "1"
        os.execv(sys.executable, [sys.executable, *sys.argv])
    j = Jarvis(cfg)
    log.info("JARVIS on http://%s:%s", cfg["host"], cfg["port"])
    web.run_app(make_app(j), host=cfg["host"], port=cfg["port"], print=None, shutdown_timeout=2)


if __name__ == "__main__":
    main()
