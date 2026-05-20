#!/usr/bin/env python3
"""
Update the MCCR Pastebins from the local ComputerCraft source files.

This script edits existing Pastebins through the normal Pastebin edit form. It
reuses Firefox cookies from a logged-in browser session, so log in to Pastebin in
Firefox first and open at least one /edit/<id> page before running this.
"""

from __future__ import annotations

import argparse
import html
import os
import shutil
import sqlite3
import sys
import tempfile
import time
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable

import requests


@dataclass(frozen=True)
class PasteTarget:
    name: str
    paste_id: str
    path: Path


ROOT = Path(__file__).resolve().parent

PASTES = [
    PasteTarget("bootloader", "GdpkSWsc", ROOT / "bootloader_startup.lua"),
    PasteTarget("maincomputer", "ueY3Fmye", ROOT / "programs" / "maincomputer" / "startup.lua"),
    PasteTarget("admin_control_panel", "cqpYrNs5", ROOT / "programs" / "admin_control_panel" / "startup.lua"),
    PasteTarget("emergency_controls_screen", "VvxgATEN", ROOT / "programs" / "emergency_controls_screen" / "startup.lua"),
    PasteTarget("action_screen", "hM9jLzcb", ROOT / "programs" / "action_screen" / "startup.lua"),
    PasteTarget("alert_level_screen", "yyDJtM4p", ROOT / "programs" / "alert_level_screen" / "startup.lua"),
    PasteTarget("clock", "Rcx37DxC", ROOT / "programs" / "clock" / "startup.lua"),
    PasteTarget("mon", "rktaUG0a", ROOT / "programs" / "mon" / "startup.lua"),
    PasteTarget("statsm", "5yTMXSLG", ROOT / "programs" / "statsm" / "startup.lua"),
    PasteTarget("presentation_screen", "zQjrdrBp", ROOT / "programs" / "presentation_screen" / "startup.lua"),
    PasteTarget("PMC", "NKrrcY8p", ROOT / "programs" / "PMC" / "startup.lua"),
    PasteTarget("peripheral", "ENtPE4DW", ROOT / "programs" / "peripheral" / "startup.lua"),
]


class PastebinFormParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.fields: list[tuple[str, str]] = []
        self._textarea_name: str | None = None
        self._textarea_text: list[str] = []
        self._select_name: str | None = None
        self._select_options: list[tuple[str, bool]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {key: value if value is not None else "" for key, value in attrs}
        name = values.get("name")
        if tag == "input" and name:
            input_type = values.get("type", "text").lower()
            if input_type in ("checkbox", "radio") and "checked" not in values:
                return
            if "disabled" in values:
                return
            self.fields.append((name, values.get("value", "")))
        elif tag == "textarea" and name:
            self._textarea_name = name
            self._textarea_text = []
        elif tag == "select" and name:
            self._select_name = name
            self._select_options = []
        elif tag == "option" and self._select_name:
            self._select_options.append((values.get("value", ""), "selected" in values))

    def handle_data(self, data: str) -> None:
        if self._textarea_name:
            self._textarea_text.append(data)

    def handle_entityref(self, name: str) -> None:
        if self._textarea_name:
            self._textarea_text.append(html.unescape(f"&{name};"))

    def handle_charref(self, name: str) -> None:
        if self._textarea_name:
            self._textarea_text.append(html.unescape(f"&#{name};"))

    def handle_endtag(self, tag: str) -> None:
        if tag == "textarea" and self._textarea_name:
            self.fields.append((self._textarea_name, "".join(self._textarea_text)))
            self._textarea_name = None
            self._textarea_text = []
        elif tag == "select" and self._select_name:
            selected = ""
            for value, is_selected in self._select_options:
                if is_selected:
                    selected = value
                    break
            if selected == "" and self._select_options:
                selected = self._select_options[0][0]
            self.fields.append((self._select_name, selected))
            self._select_name = None
            self._select_options = []


def normalize(text: str) -> str:
    return text.replace("\r\n", "\n")


def firefox_profiles() -> list[Path]:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return []
    base = Path(appdata) / "Mozilla" / "Firefox" / "Profiles"
    if not base.exists():
        return []
    return [item for item in base.iterdir() if (item / "cookies.sqlite").exists()]


def copy_cookie_db(profile: Path) -> Path:
    tmp_dir = Path(tempfile.mkdtemp(prefix="mccr_pastebin_cookies_"))
    for suffix in ("", "-wal", "-shm"):
        src = profile / f"cookies.sqlite{suffix}"
        if src.exists():
            shutil.copy2(src, tmp_dir / f"cookies.sqlite{suffix}")
    return tmp_dir


def profile_cookie_count(profile: Path) -> int:
    tmp_dir = copy_cookie_db(profile)
    try:
      con = sqlite3.connect(tmp_dir / "cookies.sqlite")
      try:
          (count,) = con.execute("select count(*) from moz_cookies where host like '%pastebin.com%'").fetchone()
          return int(count)
      finally:
          con.close()
    finally:
      shutil.rmtree(tmp_dir, ignore_errors=True)


def choose_profile(profile_arg: str | None) -> Path:
    if profile_arg:
        profile = Path(profile_arg).expanduser().resolve()
        if not (profile / "cookies.sqlite").exists():
            raise RuntimeError(f"Firefox profile has no cookies.sqlite: {profile}")
        return profile

    candidates = [(profile_cookie_count(profile), profile) for profile in firefox_profiles()]
    candidates = [(count, profile) for count, profile in candidates if count > 0]
    if not candidates:
        raise RuntimeError("No Firefox profile with Pastebin cookies was found. Log in to Pastebin in Firefox first.")
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def session_from_firefox(profile: Path) -> requests.Session:
    tmp_dir = copy_cookie_db(profile)
    jar = requests.cookies.RequestsCookieJar()
    try:
        con = sqlite3.connect(tmp_dir / "cookies.sqlite")
        try:
            rows = con.execute(
                "select host, path, name, value, isSecure, expiry "
                "from moz_cookies where host like '%pastebin.com%'"
            )
            for host, path, name, value, secure, expiry in rows:
                expires = int(expiry)
                if expires > 9_999_999_999:
                    expires = expires // 1000
                jar.set(name, value, domain=host, path=path, secure=bool(secure), expires=expires)
        finally:
            con.close()
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

    session = requests.Session()
    session.cookies.update(jar)
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Origin": "https://pastebin.com",
    })
    return session


def is_challenge(response: requests.Response) -> bool:
    text = response.text
    return (
        response.status_code == 403
        or "Just a moment" in text
        or "Nous vérifions que vous êtes humain" in text
        or "challenges.cloudflare.com" in text
    )


def edit_form(session: requests.Session, paste_id: str) -> dict[str, str]:
    url = f"https://pastebin.com/edit/{paste_id}"
    response = session.get(url, timeout=30)
    if is_challenge(response):
        raise RuntimeError(
            f"Pastebin returned a Cloudflare challenge for {paste_id}. "
            "Open Pastebin in Firefox, clear the check, then rerun this script."
        )
    if response.url.rstrip("/") == "https://pastebin.com/login" or "/login" in response.url:
        raise RuntimeError(
            f"Pastebin redirected {paste_id} to login. Log in to Pastebin in Firefox, "
            "open one edit page, then rerun this script."
        )

    parser = PastebinFormParser()
    parser.feed(response.text)
    data: dict[str, str] = {}
    for key, value in parser.fields:
        if (key.startswith("PostForm[") or key == "_csrf-frontend") and key not in data:
            data[key] = value

    if "_csrf-frontend" not in data or "PostForm[text]" not in data:
        raise RuntimeError(f"Could not read the edit form for {paste_id}; Pastebin may have changed the page.")
    return data


def update_paste(session: requests.Session, target: PasteTarget, verify_delay: float) -> str:
    local = target.path.read_text(encoding="utf-8")
    local_norm = normalize(local)
    url = f"https://pastebin.com/edit/{target.paste_id}"
    data = edit_form(session, target.paste_id)
    data["PostForm[text]"] = local

    response = session.post(url, data=data, timeout=30, allow_redirects=True, headers={"Referer": url})
    if is_challenge(response):
        raise RuntimeError(f"Pastebin blocked the edit POST for {target.name} ({target.paste_id}).")
    if response.status_code != 200:
        raise RuntimeError(f"Pastebin edit failed for {target.name} ({target.paste_id}): HTTP {response.status_code}")

    time.sleep(verify_delay)
    raw_url = f"https://pastebin.com/raw/{target.paste_id}?cb={int(time.time() * 1000)}"
    raw = session.get(raw_url, timeout=30, headers={"Cache-Control": "no-cache"})
    remote = normalize(raw.text) if raw.status_code == 200 else ""
    if remote != local_norm:
        raise RuntimeError(
            f"Verification mismatch for {target.name} ({target.paste_id}): "
            f"local={len(local_norm)} remote={len(remote)} status={raw.status_code}"
        )
    return f"{target.name:26} {target.paste_id} MATCH {len(local_norm)} chars"


def verify_raw(target: PasteTarget) -> str:
    local = normalize(target.path.read_text(encoding="utf-8"))
    raw = requests.get(
        f"https://pastebin.com/raw/{target.paste_id}?cb={int(time.time() * 1000)}",
        timeout=30,
        headers={"Cache-Control": "no-cache"},
    )
    remote = normalize(raw.text) if raw.status_code == 200 else ""
    if remote == local:
        return f"{target.name:26} {target.paste_id} MATCH"
    return f"{target.name:26} {target.paste_id} DIFF local={len(local)} remote={len(remote)} status={raw.status_code}"


def selected_targets(names: Iterable[str], include_bootloader: bool) -> list[PasteTarget]:
    wanted = {name.lower() for name in names}
    out = []
    for target in PASTES:
        if not include_bootloader and target.name == "bootloader":
            continue
        if wanted and target.name.lower() not in wanted and target.paste_id.lower() not in wanted:
            continue
        if not target.path.exists():
            raise RuntimeError(f"Missing source file for {target.name}: {target.path}")
        out.append(target)
    if wanted and not out:
        raise RuntimeError(f"No matching Pastebin targets for: {', '.join(sorted(wanted))}")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Update MCCR Pastebins from local files.")
    parser.add_argument("targets", nargs="*", help="Optional target names or Pastebin IDs to update.")
    parser.add_argument("--profile", help="Firefox profile directory to read cookies from.")
    parser.add_argument("--skip-bootloader", action="store_true", help="Do not update the bootloader Pastebin.")
    parser.add_argument("--verify-only", action="store_true", help="Only compare Pastebin raw text against local files.")
    parser.add_argument("--delay", type=float, default=1.0, help="Seconds to wait between edit and verification.")
    args = parser.parse_args()

    targets = selected_targets(args.targets, include_bootloader=not args.skip_bootloader)

    if args.verify_only:
        for target in targets:
            print(verify_raw(target))
        return 0

    profile = choose_profile(args.profile)
    print(f"Using Firefox profile: {profile}")
    session = session_from_firefox(profile)
    for target in targets:
        print(update_paste(session, target, args.delay))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
