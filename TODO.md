# TODO

- **CPU spike logger.** A small background script that records the top processes (`ps --sort=-pcpu`, load, temperature, CPU frequency)
  to a log whenever CPU stays above 80% for a few seconds, so a lag spike can be diagnosed afterwards. Idea: a systemd user service or
  a daemon started from `bspwm/start`, log under `~/.cache/`, rotate it, off switch in `power.conf`.
