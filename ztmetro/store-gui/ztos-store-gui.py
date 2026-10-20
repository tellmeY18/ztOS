#!/usr/bin/env python3
"""ztOS Store: the phone's app store.

The Store is deliberately a thin front end over two commands that are already
part of ztOS: nix search for the catalogue, and ztos-store for changes. An
install is written to the system package list and the system generation is
rebuilt, so an app stays installed across updates and rollbacks. No user
profile is involved.
"""

import json
import os
import shutil
import subprocess
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk  # noqa: E402

APP_ID = "org.ztos.Store"
STORE = shutil.which("ztos-store") or "/run/current-system/sw/bin/ztos-store"
SUDO = shutil.which("sudo") or "/run/current-system/sw/bin/sudo"
NIX = shutil.which("nix") or "/run/current-system/sw/bin/nix"
SEARCH_LIMIT = 60


def package_attr(key):
    """Turn a nix search key into an attribute usable as pkgs.<attr>."""
    for prefix in ("legacyPackages.", "packages."):
        if key.startswith(prefix):
            rest = key[len(prefix) :]
            return rest.split(".", 1)[1] if "." in rest else rest
    return key


def parse_search(data):
    found = []
    for key, meta in data.items():
        if not isinstance(meta, dict):
            continue
        attr = package_attr(key)
        name = meta.get("pname") or attr.rsplit(".", 1)[-1]
        found.append(
            {
                "attr": attr,
                "name": name,
                "version": meta.get("version") or "",
                "description": meta.get("description") or "",
            }
        )
    found.sort(key=lambda item: (item["name"].lower(), item["attr"]))
    return found


def nix_search(term):
    proc = subprocess.run(
        [NIX, "search", "nixpkgs", "--json", term],
        capture_output=True,
        text=True,
        timeout=180,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "nix search failed")
    return parse_search(json.loads(proc.stdout or "{}"))


def installed_apps():
    if not os.path.exists(STORE):
        return []
    try:
        proc = subprocess.run(
            [STORE, "installed", "--json"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if proc.returncode != 0:
            return []
        return json.loads(proc.stdout or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


class ProgressWindow(Adw.Window):
    def __init__(self, parent, title, on_done):
        super().__init__(
            transient_for=parent,
            modal=True,
            title=title,
            default_width=420,
            default_height=420,
        )
        self._on_done = on_done
        self._done = False

        toolbar = Adw.ToolbarView()
        header = Adw.HeaderBar()
        header.set_show_end_title_buttons(False)
        toolbar.add_top_bar(header)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(18)
        box.set_margin_bottom(18)
        box.set_margin_start(18)
        box.set_margin_end(18)

        self.spinner = Gtk.Spinner()
        self.spinner.set_size_request(48, 48)
        self.spinner.start()
        box.append(self.spinner)

        self.status = Gtk.Label(label="Working...")
        self.status.add_css_class("title-3")
        box.append(self.status)

        self.log = Gtk.TextView()
        self.log.set_editable(False)
        self.log.set_cursor_visible(False)
        self.log.set_monospace(True)
        self.log.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        scroll.set_child(self.log)
        box.append(scroll)

        self.close_button = Gtk.Button(label="Close")
        self.close_button.set_sensitive(False)
        self.close_button.connect("clicked", self._close)
        box.append(self.close_button)

        toolbar.set_content(box)
        self.set_content(toolbar)

    def append(self, line):
        buffer = self.log.get_buffer()
        buffer.insert(buffer.get_end_iter(), line + "\n")
        mark = buffer.create_mark(None, buffer.get_end_iter(), False)
        self.log.scroll_to_mark(mark, 0.0, True, 0.0, 0.0)
        return False

    def finish(self, code):
        self.spinner.stop()
        self.spinner.set_visible(False)
        if code == 0:
            self.status.set_label("Done")
        else:
            self.status.set_label("Could not finish")
            try:
                with open("/var/log/ztos-update.log", "r", encoding="utf-8") as log:
                    tail = log.read()[-3000:]
                if tail:
                    self.append("")
                    self.append(tail.rstrip())
            except OSError:
                pass
        self.close_button.set_sensitive(True)
        self._done = True
        return False

    def _close(self, _button):
        self.destroy()
        self._on_done(self._done)


class DetailPage(Adw.NavigationPage):
    def __init__(self, window, app, installed):
        super().__init__(title=app["name"])
        self.window = window
        self.app = app

        toolbar = Adw.ToolbarView()
        toolbar.add_top_bar(Adw.HeaderBar())

        status = Adw.StatusPage()
        status.set_title(app["name"])
        status.set_description(app["description"] or app["attr"])
        status.set_icon_name("application-x-executable-symbolic")

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_halign(Gtk.Align.CENTER)

        version = Gtk.Label(label=app["attr"] + (f"  {app['version']}" if app["version"] else ""))
        version.add_css_class("dim-label")
        version.set_selectable(True)
        version.set_wrap(True)
        box.append(version)

        self.button = Gtk.Button()
        self.button.add_css_class("pill")
        self.button.connect("clicked", self._clicked)
        box.append(self.button)

        status.set_child(box)
        toolbar.set_content(status)
        self.set_child(toolbar)
        self.set_installed(installed)

    def set_installed(self, installed):
        self._installed = installed
        if installed:
            self.button.set_label("Remove")
            self.button.remove_css_class("suggested-action")
            self.button.add_css_class("destructive-action")
        else:
            self.button.set_label("Install")
            self.button.remove_css_class("destructive-action")
            self.button.add_css_class("suggested-action")

    def _clicked(self, _button):
        if self._installed:
            self.window.uninstall(self.app)
        else:
            self.window.install(self.app)


class HomePage(Adw.NavigationPage):
    def __init__(self, window):
        super().__init__(title="Store")
        self.window = window
        self._search_source = None
        self._search_seq = 0

        toolbar = Adw.ToolbarView()
        header = Adw.HeaderBar()
        header.set_title_widget(Adw.WindowTitle(title="Store", subtitle="Apps for ztOS"))
        toolbar.add_top_bar(header)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(12)
        box.set_margin_bottom(12)
        box.set_margin_start(12)
        box.set_margin_end(12)

        self.search = Gtk.SearchEntry()
        self.search.set_placeholder_text("Search apps")
        self.search.connect("search-changed", self._changed)
        box.append(self.search)

        self.installed_group = Adw.PreferencesGroup(title="Installed")
        box.append(self.installed_group)

        self.results_group = Adw.PreferencesGroup(title="Search results")
        self.results_group.set_visible(False)
        box.append(self.results_group)

        self.status = Adw.StatusPage()
        self.status.set_icon_name("system-software-install-symbolic")
        self.status.set_title("Find an app")
        self.status.set_description(
            "Installed apps are part of your system, so they survive updates "
            "and can be rolled back with the rest of the generation."
        )
        self.status.set_vexpand(True)
        box.append(self.status)

        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        scroll.set_child(box)
        toolbar.set_content(scroll)
        self.set_child(toolbar)

    def _changed(self, entry):
        if self._search_source is not None:
            GLib.source_remove(self._search_source)
            self._search_source = None

        term = entry.get_text().strip()
        if not term:
            self._search_seq += 1
            self.results_group.set_visible(False)
            self.status.set_visible(True)
            return

        self._search_source = GLib.timeout_add(350, self._start_search, term)

    def _start_search(self, term):
        self._search_source = None
        self._search_seq += 1
        seq = self._search_seq
        self.status.set_visible(True)
        self.status.set_title("Searching...")
        self.status.set_description("Looking through nixpkgs.")
        self.results_group.set_visible(False)

        def worker():
            try:
                found = nix_search(term)
                GLib.idle_add(self._show_results, seq, term, found, None)
            except Exception as error:  # noqa: BLE001
                GLib.idle_add(self._show_results, seq, term, [], str(error))

        threading.Thread(target=worker, daemon=True).start()
        return False

    def _show_results(self, seq, term, found, error):
        if seq != self._search_seq:
            return False

        self.status.set_visible(False)
        self.results_group.set_visible(True)
        self.results_group.set_title(f'Results for "{term}"')
        self.results_group.remove_all()

        if error:
            row = Adw.ActionRow(title="Could not search", subtitle=error)
            self.results_group.add(row)
            return False

        if not found:
            row = Adw.ActionRow(title="No apps found", subtitle="Try another word.")
            self.results_group.add(row)
            return False

        installed = self.window.installed
        for app in found[:SEARCH_LIMIT]:
            row = Adw.ActionRow(title=app["name"], subtitle=app["description"] or app["attr"])
            row.set_activatable(True)
            row.connect("activated", lambda _row, item=app: self.window.show_detail(item))

            if app["attr"] in installed:
                badge = Gtk.Label(label="Installed")
                badge.add_css_class("dim-label")
                row.add_suffix(badge)
            else:
                button = Gtk.Button(label="Install")
                button.add_css_class("flat")
                button.set_valign(Gtk.Align.CENTER)
                button.connect("clicked", lambda _button, item=app: self.window.install(item))
                row.add_suffix(button)

            self.results_group.add(row)
        return False

    def refresh(self):
        self.installed_group.remove_all()
        if not self.window.installed:
            row = Adw.ActionRow(
                title="No apps yet",
                subtitle="Search above to add one.",
            )
            self.installed_group.add(row)
            return

        for attr in sorted(self.window.installed):
            row = Adw.ActionRow(title=attr, subtitle="Installed in the system")
            row.set_activatable(True)
            app = {"attr": attr, "name": attr.rsplit(".", 1)[-1], "version": "", "description": ""}
            row.connect("activated", lambda _row, item=app: self.window.show_detail(item))
            button = Gtk.Button(label="Remove")
            button.add_css_class("flat")
            button.set_valign(Gtk.Align.CENTER)
            button.connect("clicked", lambda _button, item=app: self.window.uninstall(item))
            row.add_suffix(button)
            self.installed_group.add(row)


class StoreWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Store")
        self.set_default_size(420, 820)
        self.installed = set(installed_apps())
        self.detail = None

        self.nav = Adw.NavigationView()
        self.home = HomePage(self)
        self.nav.push(self.home)
        self.set_content(self.nav)
        self.home.refresh()

    def show_detail(self, app):
        self.detail = DetailPage(self, app, app["attr"] in self.installed)
        self.nav.push(self.detail)

    def _refresh(self):
        self.installed = set(installed_apps())
        self.home.refresh()
        if self.detail is not None:
            self.detail.set_installed(self.detail.app["attr"] in self.installed)

    def _action(self, verb, app):
        attr = app["attr"]
        title = f"{verb.title()} {app['name']}"
        progress = ProgressWindow(self, title, lambda _ok: self._refresh())
        progress.present()

        argv = [SUDO, "-n", STORE, "install" if verb == "install" else "uninstall", attr]

        def worker():
            try:
                proc = subprocess.Popen(
                    argv,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                )
                for line in proc.stdout:
                    GLib.idle_add(progress.append, line.rstrip())
                code = proc.wait()
            except OSError as error:
                GLib.idle_add(progress.append, str(error))
                code = 1
            GLib.idle_add(progress.finish, code)

        threading.Thread(target=worker, daemon=True).start()

    def install(self, app):
        self._action("install", app)

    def uninstall(self, app):
        self._action("uninstall", app)


class StoreApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID)
        self.window = None

    def do_activate(self):
        if self.window is None:
            self.window = StoreWindow(self)
        self.window.present()


if __name__ == "__main__":
    StoreApp().run(None)
