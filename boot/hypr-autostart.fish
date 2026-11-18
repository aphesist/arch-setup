# Autologin on tty1 -> straight into Hyprland (Panacea locks it at once).
# Lives in fish/custom/, which Panacea keeps across updates.
#
# Never leaves an unlocked shell: when Hyprland exits, this login ends.
# Crash-loop guard: if Hyprland lasted < 15 s, drop a marker; the tty1
# getty wrapper then shows a normal password login instead of autologin,
# and this hook stays out of the way until the marker is removed
# (rm /tmp/hypr-autostart-crashed-$USER) or the next boot.
if status is-login
    and test (tty) = /dev/tty1
    and not set -q WAYLAND_DISPLAY
    and not test -e /tmp/hypr-autostart-crashed-$USER
    and not string match -q -- '*noautologin*' (cat /proc/cmdline)

    # EGL -> Mesa for Hyprland and everything it starts (see
    # ~/.config/environment.d/50-egl-mesa.conf; prime-run re-adds NVIDIA)
    set -gx __EGL_VENDOR_LIBRARY_FILENAMES /usr/share/glvnd/egl_vendor.d/50_mesa.json
    set -l t0 (date +%s)
    start-hyprland >/dev/null 2>&1
    if test (math (date +%s) - $t0) -lt 15
        touch /tmp/hypr-autostart-crashed-$USER
    end
    exit
end
