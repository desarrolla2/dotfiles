// Super+Ctrl+arrows place the focused window. Left, right and down take two
// thirds of the screen against that edge or centred and, pressed again on a
// window already there, one third, then back. Up maximizes and, pressed again,
// restores the window to where it was.
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Terminals and editors resize in whole character cells, so a window counts as
// already placed within this share of the screen width.
const TOLERANCE = 0.02;

// Keybinding names share one namespace with Mutter's own, which already has a
// "maximize", hence the prefix.
const ACTIONS = {
  'thirds-left': window => cycle(window, 'left'),
  'thirds-right': window => cycle(window, 'right'),
  'thirds-maximize': window => setMaximized(window, !isMaximized(window)),
  'thirds-center': window => cycle(window, 'center'),
};

function cycle(window, side) {
  const area = window.get_work_area_current_monitor();
  const current = window.get_frame_rect();
  const twoThirds = Math.round(area.width * 2 / 3);
  const margin = area.width * TOLERANCE;
  const atTwoThirds = Math.abs(current.x - xFor(area, side, twoThirds)) <= margin &&
    Math.abs(current.width - twoThirds) <= margin;
  const width = atTwoThirds ? area.width - twoThirds : twoThirds;
  place(window, xFor(area, side, width), area.y, width, area.height);
}

function xFor(area, side, width) {
  switch (side) {
    case 'left': return area.x;
    case 'right': return area.x + area.width - width;
    default: return area.x + Math.round((area.width - width) / 2);
  }
}

// How long a client gets to settle on a new geometry, and how many times it is
// set before giving up.
const SETTLE_MS = 150;
const ATTEMPTS = 3;

let pendingPlacement = 0;

// A maximized or half-tiled window leaves that state on the next main-loop turn,
// overwriting any geometry set before, so the geometry waits for that turn. Some
// clients, PhpStorm's Java runtime among them, then answer with their old size,
// so it is checked after a moment and set again until it holds.
// move_resize_frame() alone resizes without moving on X11: the move comes first.
function place(window, x, y, width, height) {
  setMaximized(window, false);
  cancelPlacement();

  const margin = window.get_work_area_current_monitor().width * TOLERANCE;
  let attempt = 0;
  const apply = () => {
    pendingPlacement = 0;
    if (!window.get_compositor_private())
      return GLib.SOURCE_REMOVE;

    const r = window.get_frame_rect();
    const holds = Math.abs(r.x - x) <= margin && Math.abs(r.width - width) <= margin;
    if ((attempt > 0 && holds) || attempt >= ATTEMPTS)
      return GLib.SOURCE_REMOVE;

    attempt++;
    window.move_frame(true, x, y);
    window.move_resize_frame(true, x, y, width, height);
    pendingPlacement = GLib.timeout_add(GLib.PRIORITY_DEFAULT, SETTLE_MS, apply);
    return GLib.SOURCE_REMOVE;
  };
  pendingPlacement = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, apply);
}

// focus_window is sometimes empty with a window plainly in front, so the most
// recently used window of the workspace stands in for it.
function targetWindow() {
  const focused = global.display.focus_window;
  if (focused)
    return focused;
  const workspace = global.workspace_manager.get_active_workspace();
  return global.display.get_tab_list(Meta.TabList.NORMAL, workspace)[0] ?? null;
}

function cancelPlacement() {
  if (pendingPlacement)
    GLib.source_remove(pendingPlacement);
  pendingPlacement = 0;
}

// maximize() and unmaximize() take a flags argument on some Mutter versions and
// none on others, so the flagless form is the fallback.
function setMaximized(window, maximized) {
  const method = maximized ? 'maximize' : 'unmaximize';
  try {
    window[method](Meta.MaximizeFlags.BOTH);
  } catch {
    window[method]();
  }
}

// Fully maximized only: a half-tiled window counts as maximized vertically.
// is_maximized() replaces get_maximized() on newer Mutter.
function isMaximized(window) {
  if (typeof window.is_maximized === 'function')
    return window.is_maximized();
  return window.get_maximized() === Meta.MaximizeFlags.BOTH;
}

export default class WindowThirdsExtension extends Extension {
  enable() {
    this._settings = this.getSettings();
    for (const [name, action] of Object.entries(ACTIONS)) {
      Main.wm.addKeybinding(name, this._settings, Meta.KeyBindingFlags.NONE, Shell.ActionMode.NORMAL, () => {
        const window = targetWindow();
        // Not allows_resize(): it is false for any maximized window, which is
        // exactly the one most often placed from here.
        if (window && window.get_window_type() === Meta.WindowType.NORMAL && !window.is_fullscreen())
          action(window);
      });
    }
  }

  disable() {
    cancelPlacement();
    for (const name of Object.keys(ACTIONS))
      Main.wm.removeKeybinding(name);
    this._settings = null;
  }
}
