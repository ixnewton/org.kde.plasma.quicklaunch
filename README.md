This is a re-worked version of the current org.kde.plasma.quicklaunch widget. The improvements and fixes include.

1) Updated to work with KDE Plasma 6 and Wayland desktop rendering. It has not been tested with X11
2) It works primarily with my use-case where Quicklaunch app link menus may be added to a top user panel. In my case top left next to the Kicker widget. The popup quicklink list will be dropdown in this case. I expect a bottom user panel location to also work.
3) The offset of the popup matches the position and floating style to match a floating top bar.
4) Fixing drag and drop functionality for adding external quicklinks from the Kicker menu or any folder. This was not working at all or only possible by dragging to the main header widget then with difficulty to the panel.
5) Fixing drag reorder of items in the quicklinks list. This was not working well and created duplicate items.

When it has been road tested I will try to have these improvments accepted by the official KDE repo.

Install by replacing the contents of your /usr/share/plasma/plasmoids/org.kde.plasma.quicklaunch/ with the downloaded version from here.

Restart KDE Plasma using: kquitapp5 plasmashell && kstart5 plasmashell
