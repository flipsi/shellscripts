#!/bin/env fish

# initial desktop setup on obelix with i3 window manager for external monitor
# (because it does not what i want by itself)
# should be executed after i3 startup

if test (hostname) = 'obelix'
    if xrandr | grep 'VGA-0 connected'
        sleep 7
        xrandr --output VGA-0 --auto --below LVDS-0
        i3-msg restart
        feh --bg-scale ~/.i3/wallpaper
        echo 'Setup completed.'
    end
end
