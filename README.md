# Plugin Refresher

A simple plugin refresher for 4.x, mounts as a button on the toolbar which scans your plugins and allow refreshing them without having to go to Project Settings.

It also keeps the current main screen open if possible.

### Small Issues

- Given how the Godot editor works, the plugin refresher won't be able to keep the main screen open until you switch to a new main screen for the first time after you enable this plugin. That's because the plugin needs to keep track of your main screen with a signal and can't directly retrieve the current selected screen.
