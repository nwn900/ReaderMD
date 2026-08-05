on run arguments
    if (count of arguments) is not 2 then error "Expected volume name and app filename."

    set volumeName to item 1 of arguments
    set appFilename to item 2 of arguments

    using terms from application "Finder"
        tell application "Finder"
            tell disk (volumeName as text)
            open
            set dmgWindow to container window
            set current view of dmgWindow to icon view
            set toolbar visible of dmgWindow to false
            set statusbar visible of dmgWindow to false
            set pathbar visible of dmgWindow to false
            set bounds of dmgWindow to {100, 100, 900, 640}

            set viewOptions to icon view options of dmgWindow
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 160
            set text size of viewOptions to 14
            set shows item info of viewOptions to false
            set shows icon preview of viewOptions to true
            set background picture of viewOptions to file ".background:background.png"

            set position of item appFilename to {220, 270}
            set position of item "Applications" to {580, 270}
            set extension hidden of item appFilename to true

            update without registering applications
            delay 2
            close dmgWindow
            end tell
        end tell
    end using terms from

    delay 1
end run
