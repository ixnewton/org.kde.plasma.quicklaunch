This is a re-worked version of the current org.kde.plasma.quicklaunch widget. The improvements and fixes include.

1) Updated to work with KDE Plasma 6 and Wayland desktop rendering. It has not been tested with X11
2) It works primarily with my use-case where Quicklaunch app link menus may be added to a top user panel. I use it for favorites quick links top left next to the Kicker widget. The popup quicklink list will be dropdown in this case. I expect a bottom user panel location to also work.
3) Multiple widgets placed next to each other, which may be for different categories of apps, work well with each other's popup opening/closing. 
4) The offset of the popup matches the position and floating style to match a floating top bar.
5) Fixing drag and drop functionality for adding external quicklinks from the Kicker menu or any folder. This was not working at all or only possible by dragging to the main header widget then with difficulty to the panel.
6) Fixing drag reorder of items in the quicklinks list. This was not working well and created duplicate items.
7) TBD: Dragging between popup list and the main widget is not ideal resulting in orphaned coppies at the source. Unifying the main and popup lists as a single list may be the solution showing the first item in the top main area and the rest in the popup. Dragging to reorder/reposition should then work as a single list.

When it has been road tested I will try to have these improvments accepted by the official KDE repo.

Install by replacing the contents of your /usr/share/plasma/plasmoids/org.kde.plasma.quicklaunch/ with the downloaded version from here.

Restart KDE Plasma using: kquitapp5 plasmashell && kstart5 plasmashell

![Screenshot_20250702_221558_b](https://github.com/user-attachments/assets/2bdd486f-25dc-4452-bd96-601fda6da54c)
