#!/usr/bin/env python3
"""Run a Logos blockchain node with logosctl 0.3.2, or report the failure.

Session files go under data/logos-node and are not part of the repo.
Keystore and user config are never printed.
"""

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "logos-node"
SESSION = DATA / "session"
MODULE = "blockchain_module"
VERSION = "0.3.2"
ROOT_HASH = "9ab4acbb734a85b0271f88d6db87f6d6ca3c6d96a3b27bacaa4ab11f67b6f0d7"
PEERS = {
    "initial_peers": [
        "/ip4/65.109.51.37/udp/3000/quic-v1/p2p/12D3KooWFrouXfmrR4nsLMtE7wu15DoMJ6VtoUtHinREZCvbWHar",
        "/ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWJRGau8M1rjT7R5e4YYsgdFhsMX35nRDtMwCDjxQkXAHz",
        "/ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWQXJavMDTRscjauFSgVAB1VLB6Rzpy2uY5SU9Tk7927tb",
        "/ip4/65.109.51.37/udp/50001/quic-v1/p2p/12D3KooWSQc7CcGtvWDPF1yCbBthFnQjprfCVHmfmNDUrSmqQsU1",
    ]
}

REDACT = ("private_key", "privatekey", "mnemonic", "keystore", "secret_key")


def find_logosctl():
    chosen = os.environ.get("LOGOSCTL")
    if chosen and Path(chosen).is_file():
        return Path(chosen)
    local = ROOT / "bin" / "logosctl"
    if local.is_file():
        return local
    found = shutil.which("logosctl")
    return Path(found) if found else None


def emit(ok, summary, detail):
    json.dump({"ok": ok, "summary": summary, "detail": detail}, sys.stdout)
    sys.stdout.write("\n")


def redact(text):
    kept = []
    for line in (text or "").splitlines():
        low = line.lower()
        if any(word in low for word in REDACT):
            continue
        kept.append(line)
    return "\n".join(kept)[-1600:]


def summarize_info(raw):
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return redact(raw)[:500]
    value = payload.get("result", payload)
    if isinstance(value, dict) and "value" in value:
        value = value["value"]
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return value[:500]
    if isinstance(value, dict) and ("mode" in value or "height" in value):
        return "Mode {mode}. Height {height}. Slot {slot}.".format(
            mode=value.get("mode", "unknown"),
            height=value.get("height", "?"),
            slot=value.get("slot", "?"),
        )
    return redact(json.dumps(value))[:500]


def chain_running(raw):
    text = raw or ""
    return '"height"' in text or '"mode"' in text or "Bootstrapping" in text or "Online" in text


class Runner:
    def __init__(self, binary):
        self.binary = binary
        self.env = os.environ.copy()
        self.env["LOGOSCTL_CONFIG_DIR"] = str(SESSION)
        self.env["HOME"] = str(DATA)
        self.env["APPIMAGE_EXTRACT_AND_RUN"] = "1"
        DATA.mkdir(parents=True, exist_ok=True)
        SESSION.mkdir(parents=True, exist_ok=True)

    def run(self, args, timeout=90, check=True, stdin=None):
        proc = subprocess.run(
            [str(self.binary), *args],
            cwd=DATA,
            env=self.env,
            input=stdin,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if check and proc.returncode != 0:
            raise RuntimeError(redact((proc.stderr or "") + "\n" + (proc.stdout or "")))
        return proc

    def daemon_running(self):
        proc = self.run(["daemon", "status"], timeout=20, check=False)
        if proc.returncode != 0:
            return False
        try:
            body = json.loads(proc.stdout)
        except json.JSONDecodeError:
            return "running" in proc.stdout
        return body.get("daemon", {}).get("status") == "running"

    def module_loaded(self):
        proc = self.run(["module", "ls"], timeout=20, check=False)
        if proc.returncode != 0:
            return False
        try:
            rows = json.loads(proc.stdout)
        except json.JSONDecodeError:
            return MODULE in proc.stdout
        return any(row.get("name") == MODULE and row.get("status") == "loaded" for row in rows)

    def ensure_daemon(self):
        if self.daemon_running():
            return
        config = SESSION / "daemon" / "config.yaml"
        if not config.is_file():
            self.run(["daemon", "config", "set", "-"], stdin="{}\n", timeout=30)
        self.run(["daemon", "start", "--detach"], timeout=90)

    def ensure_module(self):
        if self.module_loaded():
            return
        loaded = self.run(["module", "load", MODULE], timeout=120, check=False)
        if loaded.returncode == 0:
            return
        self.run(["catalog", "refresh"], timeout=180)
        self.run(
            ["package", "install", MODULE, "--version", VERSION, "--root-hash", ROOT_HASH, "--yes"],
            timeout=300,
        )
        self.run(["module", "load", MODULE], timeout=120)

    def find_config(self):
        matches = sorted(DATA.rglob("user_config.yaml"))
        return matches[0] if matches else None

    def lock_down(self):
        for name in ("user_config.yaml", "keystore.yaml"):
            for path in DATA.rglob(name):
                path.chmod(0o600)

    def read_info(self):
        try:
            proc = self.run(["call", MODULE, "get_cryptarchia_info"], timeout=20, check=False)
        except subprocess.TimeoutExpired:
            return ""
        if proc.returncode != 0:
            return ""
        return proc.stdout

    def go(self):
        self.ensure_daemon()
        self.ensure_module()
        info = self.read_info()
        if chain_running(info):
            return summarize_info(info)
        config = self.find_config()
        if config is None:
            peers = DATA / "peers.json"
            peers.write_text(json.dumps(PEERS))
            self.run(["call", MODULE, "generate_user_config", f"@{peers}"], timeout=120)
            self.lock_down()
            config = self.find_config()
        if config is None:
            raise RuntimeError("generate_user_config did not write user_config.yaml")
        self.run(["call", MODULE, "start", str(config), ""], timeout=180)
        info = self.read_info()
        if not chain_running(info):
            raise RuntimeError(redact(info) or "start returned, but get_cryptarchia_info had no chain status")
        summary = summarize_info(info)
        if "Height 0" in summary:
            time.sleep(2)
            again = self.read_info()
            if chain_running(again):
                summary = summarize_info(again)
        return summary


def main():
    binary = find_logosctl()
    if binary is None:
        emit(
            False,
            "The node did not start.",
            "logosctl 0.3.2 is not installed. Looked for $LOGOSCTL, bin/logosctl, and PATH. Nothing was started.",
        )
        return 0
    try:
        detail = Runner(binary).go()
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as exc:
        emit(False, "The node did not start.", redact(str(exc)))
        return 0
    emit(True, "The node is running. Later tasks will be added.", detail)
    return 0


if __name__ == "__main__":
    sys.exit(main())
