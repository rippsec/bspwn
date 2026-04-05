// user.js — Firefox ESR performance tuning for T450 i5-5300U / Intel iHD VA-API
// Applied by: install.sh or manually dropped into the profile directory.
// Firefox reads this on every startup and it overrides prefs.js entries.

// ---------------------------------------------------------------------------
// Hardware video decode — VA-API via system ffmpeg (Intel iHD driver)
// Primary fix for 100% CPU during video playback.
// Requires: LIBVA_DRIVER_NAME=iHD set in session (bspwmrc), user in render group.
// ---------------------------------------------------------------------------
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.ffmpeg.vaapi-drm-display.enabled", true);

// ---------------------------------------------------------------------------
// GPU compositing — WebRender (GPU-accelerated compositor)
// Reduces CPU used for painting/compositing pages.
// Intel Broadwell (Gen8) supports WebRender via Mesa/i965.
// ---------------------------------------------------------------------------
user_pref("gfx.webrender.all", true);
user_pref("gfx.canvas.accelerated", true);
user_pref("layers.acceleration.force-enabled", true);

// ---------------------------------------------------------------------------
// Content process count
// Default is 8 processes; T450 has 4 threads — 8 renderers cause CPU contention.
// 4 = one renderer per CPU thread, still enough for typical pentest workflow.
// ---------------------------------------------------------------------------
user_pref("dom.ipc.processCount", 4);
user_pref("dom.ipc.processCount.webIsolated", 2);

// ---------------------------------------------------------------------------
// Background tab throttling
// Throttle timers and RAF in background tabs (default already does this,
// but these values make it more aggressive to free CPU for active tab).
// ---------------------------------------------------------------------------
user_pref("dom.min_background_timeout_value", 1000);
user_pref("dom.timeout.throttling_delay", 50);

// ---------------------------------------------------------------------------
// Session autosave — reduce disk write frequency
// Default 15000ms writes session every 15s; 60s is enough.
// Reduces I/O and CPU overhead from frequent serialization.
// ---------------------------------------------------------------------------
user_pref("browser.sessionstore.interval", 60000);

// ---------------------------------------------------------------------------
// Memory management
// Trim working set when Firefox window is minimized.
// ---------------------------------------------------------------------------
user_pref("config.trim_on_minimize", true);

// ---------------------------------------------------------------------------
// Telemetry — disable background CPU/network overhead
// ---------------------------------------------------------------------------
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.ping-centre.telemetry", false);

// ---------------------------------------------------------------------------
// Link prefetch — disable speculative fetches that waste CPU/bandwidth
// ---------------------------------------------------------------------------
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
