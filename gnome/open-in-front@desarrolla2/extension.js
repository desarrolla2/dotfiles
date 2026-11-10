// A link opened from tmux (bin/tmux-open-link) reaches its app with no activation
// token, since tmux has no window to lend one, so Mutter leaves the app behind with
// a "ready" notice. The script touches MARKER right before it opens the link; the
// first window that asks for attention within SECONDS of that is brought to the
// front. Any other request for attention, a chat app flagging a message, keeps its
// notice and nothing more.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const MARKER = GLib.build_filenamev([GLib.get_user_runtime_dir(), 'open-in-front']);
const SECONDS = 5;

function armed(file) {
  try {
    const info = file.query_info('time::modified', Gio.FileQueryInfoFlags.NONE, null);
    return GLib.get_real_time() / 1e6 - info.get_modification_date_time().to_unix() <= SECONDS;
  } catch {
    return false;
  }
}

export default class OpenInFrontExtension extends Extension {
  enable() {
    const marker = Gio.File.new_for_path(MARKER);
    this._handler = global.display.connect('window-demands-attention', (_display, window) => {
      if (!armed(marker)) {
        return;
      }
      // One link, one window: a second request in the same seconds keeps its notice.
      try {
        marker.delete(null);
      } catch {
        // Already gone: nothing to disarm.
      }
      Main.activateWindow(window);
    });
  }

  disable() {
    global.display.disconnect(this._handler);
    this._handler = null;
  }
}
