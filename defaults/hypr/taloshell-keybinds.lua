-- taloshell extra keybinds (Hyprland Lua config, 0.55+)
-- Load it from ~/.config/hypr/custom/keybinds.lua with:
--   dofile(os.getenv("HOME") .. "/.config/quickshell/taloshell/defaults/hypr/taloshell-keybinds.lua")
-- The usual illogical-impulse binds keep working: with launcher.engine = "talos",
-- Super (release), Super+V (clipboard) and Super+. (emoji) open the Talos launcher.

-- Dashboard
hl.bind("SUPER + D", hl.dsp.global("quickshell:dashboardToggle"), { description = "taloshell: dashboard" })
hl.bind("SUPER + SHIFT + D", hl.dsp.global("quickshell:dashboardTasks"), { description = "taloshell: tasks board" })
hl.bind("SUPER + CTRL + D", hl.dsp.global("quickshell:dashboardPerformance"), { description = "taloshell: performance" })

-- Launcher modes
hl.bind("SUPER + R", hl.dsp.global("quickshell:launcherCommands"), { description = "taloshell: commands" })
hl.bind("SUPER + SHIFT + T", hl.dsp.global("quickshell:launcherThemes"), { description = "taloshell: pick a theme" })
hl.bind("SUPER + SHIFT + W", hl.dsp.global("quickshell:launcherWindows"), { description = "taloshell: switch window" })
hl.bind("SUPER + SHIFT + F", hl.dsp.global("quickshell:launcherFiles"), { description = "taloshell: find files" })

-- Screen recorder
hl.bind("SUPER + SHIFT + R", hl.dsp.global("quickshell:recorderToggle"), { description = "taloshell: start/stop recording" })
hl.bind("SUPER + CTRL + R", hl.dsp.global("quickshell:recorderPanel"), { description = "taloshell: recorder options" })
