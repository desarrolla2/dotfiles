// Super+Ctrl+arrows place the focused window. Left and right take two thirds of
// the screen against that edge and, pressed again on a window already there, one
// third, then back. Up maximizes, down centres two thirds.
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Terminals and editors resize in whole character cells, so a window counts as
// already placed within this share of the screen width.
const TOLERANCE = 0.02;

const ACTIONS = {
  'tile-left': window => tileAgainst(window, 'left'),
  'tile-right': window => tileAgainst(window, 'right'),
  'maximize': window => setMaximized(window, true),
  'center': window => center(window),
};

function tileAgainst(window, side) {
  const area = window.get_work_area_current_monitor();
  const current = window.get_frame_rect();
  const twoThirds = Math.round(area.width * 2 / 3);
  const margin = area.width * TOLERANCE;
  const gap = side === 'left'
    ? current.x - area.x
    : area.x + area.width - (current.x + current.width);
  const atTwoThirds = Math.abs(gap) <= margin && Math.abs(current.width - twoThirds) <= margin;
  const width = atTwoThirds ? area.width - twoThirds : twoThirds;
  const x = side === 'left' ? area.x : area.x + area.width - width;
  place(window, x, area.y, width, area.height);
}

function center(window) {
  const area = window.get_work_area_current_monitor();
  const width = Math.round(area.width * 2 / 3);
  place(window, area.x + Math.round((area.width - width) / 2), area.y, width, area.height);
}

// A maximized or half-tiled window ignores a new geometry until it leaves that state.
function place(window, x, y, width, height) {
  setMaximized(window, false);
  window.move_resize_frame(true, x, y, width, height);
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

export default class WindowThirdsExtension extends Extension {
  enable() {
    this._settings = this.getSettings();
    for (const [name, action] of Object.entries(ACTIONS)) {
      Main.wm.addKeybinding(name, this._settings, Meta.KeyBindingFlags.NONE, Shell.ActionMode.NORMAL, () => {
        const window = global.display.focus_window;
        if (window && !window.is_fullscreen() && window.allows_resize())
          action(window);
      });
    }
  }

  disable() {
    for (const name of Object.keys(ACTIONS))
      Main.wm.removeKeybinding(name);
    this._settings = null;
  }
}
