#!/bin/sh
	export QT_QPA_PLATFORM=wayland
    # export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_DESKTOP=sway
    export MOZ_DBUS_REMOTE=1
    export QT_QPA_PLATFORMTHEME=qt5ct
	export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
	export QT_WAYLAND_FORCE_DPI=physical
    export SUBLIME_WAYLAND=1
exec sway
