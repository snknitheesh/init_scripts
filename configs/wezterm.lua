-- WezTerm set up like the Terminator profile.
local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Native Wayland renders crisp at fractional scaling. The WebGpu (Vulkan)
-- renderer fails to import dmabufs on NVIDIA under GNOME, so use OpenGL.
config.enable_wayland = true
config.front_end = 'OpenGL'
-- Match the 120 Hz panel instead of the 60 fps default.
config.max_fps = 120

-- System font, green on black, Terminator's Tango palette.
config.font = wezterm.font 'Ubuntu Sans Mono'
config.font_size = 11.0
config.colors = {
  foreground = '#00ff00',
  background = '#000000',
  cursor_bg = '#00ff00',
  cursor_fg = '#000000',
  cursor_border = '#00ff00',
  selection_fg = '#000000',
  selection_bg = '#00ff00',
  ansi = { '#2e3436', '#cc0000', '#4e9a06', '#c4a000', '#3465a4', '#75507b', '#06989a', '#d3d7cf' },
  brights = { '#555753', '#ef2929', '#8ae234', '#fce94f', '#729fcf', '#ad7fa8', '#34e2e2', '#eeeeec' },
}

-- WezTerm keeps scrollback in RAM, so "infinite" is a very large number of lines.
config.scrollback_lines = 1000000
config.enable_scroll_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.audible_bell = 'Disabled'
config.window_close_confirmation = 'NeverPrompt'

-- Terminator's Ctrl+Shift+Z: maximise the pane and enlarge its text; again restores both.
local function scaled_zoom(window, pane)
  local tab = pane:tab()
  local zoomed = false
  for _, p in ipairs(tab:panes_with_info()) do
    if p.is_zoomed then
      zoomed = true
    end
  end
  local overrides = window:get_config_overrides() or {}
  if zoomed then
    tab:set_zoomed(false)
    overrides.font_size = nil
  else
    tab:set_zoomed(true)
    overrides.font_size = 15.0
  end
  window:set_config_overrides(overrides)
end

config.keys = {
  -- Copy and paste as in Terminator. Ctrl+C copies only when text is
  -- selected; otherwise it still interrupts the program.
  {
    key = 'c',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      if window:get_selection_text_for_pane(pane) ~= '' then
        window:perform_action(act.CopyTo 'ClipboardAndPrimarySelection', pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end),
  },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },

  -- Splits: O stacks top/bottom, E puts side by side, W closes.
  { key = 'O', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'E', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'W', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },

  -- Maximise the pane (X), or maximise with bigger text (Z).
  { key = 'X', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },
  { key = 'Z', mods = 'CTRL|SHIFT', action = wezterm.action_callback(scaled_zoom) },

  -- Move between panes with Alt+arrows, resize with Ctrl+Shift+arrows.
  { key = 'LeftArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'LeftArrow', mods = 'CTRL|SHIFT', action = act.AdjustPaneSize { 'Left', 3 } },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.AdjustPaneSize { 'Right', 3 } },
  { key = 'UpArrow', mods = 'CTRL|SHIFT', action = act.AdjustPaneSize { 'Up', 3 } },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = act.AdjustPaneSize { 'Down', 3 } },

  -- No keyboard copy: copy mode and quick select are off, and so are the
  -- Ctrl+Shift+C / V duplicates, as in this Terminator setup.
  { key = 'Space', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = 'C', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = 'V', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
}

-- Mouse wheel scrolls three lines per notch instead of the default jump.
-- alt_screen = false leaves full-screen apps (vim, less, htop) unchanged.
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = { WheelUp = 1 } } },
    mods = 'NONE',
    alt_screen = false,
    action = act.ScrollByLine(-3),
  },
  {
    event = { Down = { streak = 1, button = { WheelDown = 1 } } },
    mods = 'NONE',
    alt_screen = false,
    action = act.ScrollByLine(3),
  },
}

return config
