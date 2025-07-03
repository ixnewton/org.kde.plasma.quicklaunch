/*
 *  SPDX-FileCopyrightText: 2015 David Rosca <nowrep@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick 2.15
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid 2.0
import org.kde.draganddrop 2.0 as DragAndDrop
import org.kde.plasma.extras 2.0 as PlasmaExtras

import "layout.js" as LayoutManager

Item {
    id: iconItem

    readonly property int itemIndex : index
    property bool dragging : false
    property bool isPopupItem : false
    readonly property var launcher : logic.launcherData(url)
    readonly property string iconName : launcher.iconName || "fork"

    width: isPopupItem ? LayoutManager.popupItemWidth() : grid.cellWidth
    height: isPopupItem ? LayoutManager.popupItemHeight() : grid.cellHeight

    Keys.onPressed: {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Select:
            logic.openUrl(url);
            break;
        case Qt.Key_Menu:
            contextMenu.refreshActions();
            contextMenu.open(0,0);
            event.accepted = true;
            break;
        case Qt.Key_Backspace:
        case Qt.Key_Delete:
            removeLauncher();
            event.accepted = true;
            break;
        }

        // BEGIN Arrow keys
        if (!(event.modifiers & Qt.ControlModifier) || !(event.modifiers & Qt.ShiftModifier)) {
            return;
        }

        switch (event.key) {
        case Qt.Key_Up: {
            if (iconItem.isPopupItem && iconItem.itemIndex === 0 && Plasmoid.location === PlasmaCore.Types.TopEdge) {
                iconItem.ListView.view.moveItemToGrid(iconItem, url);
                break;
            } else if (!iconItem.isPopupItem && Plasmoid.location === PlasmaCore.Types.BottomEdge) {
                iconItem.GridView.view.moveItemToPopup(iconItem, url);
                break;
            }

            decreaseIndex();
            break;
        }

        case Qt.Key_Down: {
            if (iconItem.isPopupItem && iconItem.itemIndex === iconItem.ListView.view.count - 1 && Plasmoid.location === PlasmaCore.Types.BottomEdge) {
                iconItem.ListView.view.moveItemToGrid(iconItem, url);
                break;
            } else if (!iconItem.isPopupItem && Plasmoid.location === PlasmaCore.Types.TopEdge) {
                iconItem.GridView.view.moveItemToPopup(iconItem, url);
                break;
            }

            increaseIndex();
            break;
        }

        case Qt.Key_Left: {
            if (iconItem.isPopupItem && Plasmoid.location === PlasmaCore.Types.LeftEdge) {
                iconItem.ListView.view.moveItemToGrid(iconItem, url);
                break;
            } else if (!iconItem.isPopupItem && Plasmoid.location === PlasmaCore.Types.RightEdge) {
                iconItem.GridView.view.moveItemToPopup(iconItem, url);
                break;
            }

            decreaseIndex();
            break;
        }
        case Qt.Key_Right: {
            if (iconItem.isPopupItem && Plasmoid.location === PlasmaCore.Types.RightEdge) {
                iconItem.ListView.view.moveItemToGrid(iconItem, url);
                break;
            } else if (!iconItem.isPopupItem && Plasmoid.location === PlasmaCore.Types.LeftEdge) {
                iconItem.GridView.view.moveItemToPopup(iconItem, url);
                break;
            }

            increaseIndex();
            break;
        }
        default:
            return;
        }

        event.accepted = true;
        // END Arrow keys
    }

    function decreaseIndex() {
        const newIndex = iconItem.itemIndex - 1;
        if (newIndex < 0) {
            return;
        }
        if (iconItem.isPopupItem) {
            popupModel.moveUrl(iconItem.itemIndex, newIndex);
            iconItem.ListView.view.currentIndex = newIndex;
        } else {
            launcherModel.moveUrl(iconItem.itemIndex, newIndex);
            iconItem.GridView.view.currentIndex = newIndex;
        }
    }

    function increaseIndex() {
        const newIndex = iconItem.itemIndex + 1;
        if (newIndex === (iconItem.isPopupItem ? iconItem.ListView.view.count : iconItem.GridView.view.count)) {
            return;
        }
        if (iconItem.isPopupItem) {
            popupModel.moveUrl(iconItem.itemIndex, newIndex);
            iconItem.ListView.view.currentIndex = newIndex;
        } else {
            launcherModel.moveUrl(iconItem.itemIndex, newIndex);
            iconItem.GridView.view.currentIndex = newIndex;
        }
    }



    DragAndDrop.DragArea {
        id: dragArea
        width: Math.min(iconItem.width, iconItem.height)
        height: width
        enabled: !plasmoid.immutable
        defaultAction: Qt.MoveAction
        supportedActions: Qt.IgnoreAction | Qt.MoveAction
        delegate: icon
        source: iconItem  // Pass the iconItem as source for internal drag detection

        mimeData {
            url: url
        }

        onDragStarted: {
            // console.log("[DEBUG] IconItem drag started - isPopupItem:", isPopupItem, "itemIndex:", iconItem.itemIndex, "url:", url);
            
            // Set global internal drag flags for both popup and main widget items
            if (isPopupItem && iconItem.ListView && iconItem.ListView.view && iconItem.ListView.view.parent) {
                // Handle popup item drag
                var popup = iconItem.ListView.view.parent;
                if (popup.internalDragActive !== undefined) {
                    popup.internalDragActive = true;
                    popup.internalDragSourceIndex = iconItem.itemIndex;
                    console.log("[DEBUG] Popup drag flags set - sourceIndex:", iconItem.itemIndex);
                }
            } else if (!isPopupItem && iconItem.GridView && iconItem.GridView.view) {
                // Handle main widget item drag - find root widget
                var rootWidget = iconItem.GridView.view;
                while (rootWidget && rootWidget.internalDragActive === undefined) {
                    rootWidget = rootWidget.parent;
                }
                if (rootWidget && rootWidget.internalDragActive !== undefined) {
                    rootWidget.internalDragActive = true;
                    rootWidget.internalDragSourceIndex = iconItem.itemIndex;
                    console.log("[DEBUG] Main widget drag flags set - sourceIndex:", iconItem.itemIndex);
                } else {
                    console.log("[DEBUG] Could not find root widget for main item drag");
                }
            }
            
            dragging = true;
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            anchors.margins: LayoutManager.itemPadding()
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton  // Only left button for normal interaction

            activeFocusOnTab: true
            Accessible.name: iconItem.launcher.applicationName
            Accessible.description: i18n("Launch %1", iconItem.launcher.genericName || iconItem.launcher.applicationName)
            Accessible.role: Accessible.Button

            onActiveFocusChanged: {
                // console.log("[DEBUG] IconItem", itemIndex, "activeFocusChanged:", activeFocus);
                if (activeFocus) {
                    // console.log("[DEBUG] IconItem", itemIndex, "gained focus, calling entered()");
                    entered();
                }
            }

            onEntered: {
                // console.log("[DEBUG] IconItem", itemIndex, "onEntered - setting highlight");
                // Set highlight to follow mouse hover
                if (iconItem.ListView.view) {
                    iconItem.ListView.view.currentIndex = iconItem.itemIndex;
                }
                if (iconItem.GridView.view) {
                    iconItem.GridView.view.currentIndex = iconItem.itemIndex;
                }
            }

            onExited: {
                // console.log("[DEBUG] IconItem", itemIndex, "onExited");
                // Highlight will naturally change when mouse enters another item
                // No special handling needed on exit
            }

            onPressed: function(mouse) {
                // console.log("[DEBUG] IconItem", itemIndex, "onPressed - button:", mouse.button, "(Left:", Qt.LeftButton, ")");
                // Only handle left button here - right button handled separately
            }

            onPressAndHold: function(mouse) {
                // Explicitly handle pressAndHold to prevent any default behavior
                // Do nothing - this prevents long press from triggering selection
                mouse.accepted = true;
            }

            onClicked: function(mouse) {
                // console.log("[DEBUG] IconItem", itemIndex, "onClicked - button:", mouse.button, "(Left:", Qt.LeftButton, ")");
                if (mouse.button == Qt.LeftButton) {
                    // Left click now toggles selection instead of opening URL
                    // console.log("[DEBUG] IconItem", itemIndex, "left-click detected, toggling selection");
                    var currentIndex = -1;
                    if (iconItem.ListView.view) {
                        currentIndex = iconItem.ListView.view.currentIndex;
                    } else if (iconItem.GridView.view) {
                        currentIndex = iconItem.GridView.view.currentIndex;
                    }
                    
                    if (currentIndex === iconItem.itemIndex) {
                        // Currently selected - deselect by setting to -1
                        // console.log("[DEBUG] IconItem", itemIndex, "deselecting (was selected)");
                        if (iconItem.ListView.view) {
                            iconItem.ListView.view.currentIndex = -1;
                        }
                        if (iconItem.GridView.view) {
                            iconItem.GridView.view.currentIndex = -1;
                        }
                    } else {
                        // Not currently selected - select this item
                        // console.log("[DEBUG] IconItem", itemIndex, "selecting (was not selected)");
                        if (iconItem.ListView.view) {
                            iconItem.ListView.view.currentIndex = iconItem.itemIndex;
                        }
                        if (iconItem.GridView.view) {
                            iconItem.GridView.view.currentIndex = iconItem.itemIndex;
                        }
                    }
                }
            }
            
            onDoubleClicked: function(mouse) {
                // Double-click opens the URL (moved from single click)
                if (mouse.button == Qt.LeftButton) {
                    // console.log("[DEBUG] IconItem", itemIndex, "double-click detected, opening URL:", url);
                    logic.openUrl(url);
                }
            }

            Kirigami.Icon {
                id: icon

                anchors {
                    top: parent.top
                    left: parent.left
                }

                width: Kirigami.Units.iconSizes.medium
                height: width
                source: url == "quicklaunch:drop" ? "" : iconName
                active: mouseArea.containsMouse
            }

            PlasmaComponents3.Label {
                id: label

                anchors {
                    bottom : parent.bottom
                    right : parent.right
                }

                text: iconItem.launcher.applicationName
                textFormat: Text.PlainText
                maximumLineCount: 1
                wrapMode: Text.Wrap
            }

            KSvg.FrameSvgItem {
                anchors.fill: parent
                imagePath: "widgets/viewitem"
                prefix: "hover"
                visible: dragging || url == "quicklaunch:drop"
            }

            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                active: !dragging
                mainText: iconItem.launcher.applicationName
                subText: iconItem.launcher.genericName
                icon: iconName
            }

            PlasmaExtras.Menu {
                id: contextMenu

                property var jumpListItems : []

                visualParent: mouseArea

                PlasmaExtras.MenuItem {
                    id: jumpListSeparator
                    separator: true
                }

                PlasmaExtras.MenuItem {
                    text: i18nc("@action:inmenu", "Add Launcher…")
                    icon: "list-add"
                    onClicked: addLauncher()
                }

                PlasmaExtras.MenuItem {
                    text: i18nc("@action:inmenu", "Edit Launcher…")
                    icon: "document-edit"
                    onClicked: {
                        console.log("[DEBUG] IconItem", itemIndex, "Edit Launcher clicked");
                        editLauncher();
                    }
                }

                PlasmaExtras.MenuItem {
                    text: i18nc("@action:inmenu", "Remove Launcher")
                    icon: "list-remove"
                    onClicked: removeLauncher()
                }

                PlasmaExtras.MenuItem {
                    separator: true
                }

                PlasmaExtras.MenuItem {
                    action: Plasmoid.internalAction("configure")
                }

                PlasmaExtras.MenuItem {
                    action: Plasmoid.internalAction("remove")
                }

                function refreshActions() {
                    for (var i = 0; i < jumpListItems.length; ++i) {
                        var item = jumpListItems[i];
                        removeMenuItem(item);
                        item.destroy();
                    }
                    jumpListItems = [];

                    for (var i = 0; i < launcher.jumpListActions.length; ++i) {
                        var action = launcher.jumpListActions[i];
                        var item = menuItemComponent.createObject(iconItem, {
                            "text": action.name,
                            "icon": action.icon
                        });
                        item.clicked.connect(function() {
                            logic.openExec(this.exec);
                        }.bind(action));

                        addMenuItem(item, jumpListSeparator);
                        jumpListItems.push(item);
                    }
                }
            }

            Component {
                id: menuItemComponent
                PlasmaExtras.MenuItem { }
            }
        }
    }

    // Separate MouseArea for right-click to prevent selection highlight
    MouseArea {
        id: rightClickArea
        anchors.fill: parent
        anchors.margins: LayoutManager.itemPadding()
        acceptedButtons: Qt.RightButton
        hoverEnabled: false  // Don't interfere with hover from main MouseArea
        
        onPressed: function(mouse) {
            // console.log("[DEBUG] IconItem", itemIndex, "right-click detected, opening context menu (no selection)");
            contextMenu.open(mouse.x, mouse.y);
        }
    }

    states: [
        State {
            name: "popup"
            when: isPopupItem

            AnchorChanges {
                target: dragArea
                anchors.left: dragArea.parent.left
                anchors.right: dragArea.parent.right
                anchors.top: dragArea.parent.top
                anchors.bottom: dragArea.parent.bottom
            }

            AnchorChanges {
                target: icon
                anchors.right: undefined
                anchors.bottom: undefined
            }

            AnchorChanges {
                target: label
                anchors.top: label.parent.top
                anchors.left: icon.right
            }

            PropertyChanges {
                target: label
                horizontalAlignment: Text.AlignHLeft
                visible: true
                elide: Text.ElideRight
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
            }
        },

        State {
            name: "grid"
            when: !isPopupItem

            AnchorChanges {
                target: dragArea
                anchors.verticalCenter: dragArea.parent.verticalCenter
                anchors.horizontalCenter: dragArea.parent.horizontalCenter
            }

            AnchorChanges {
                target: icon
                anchors.right: icon.parent.right
                anchors.bottom: label.visible ? label.top : icon.parent.bottom
            }

            AnchorChanges {
                target: label
                anchors.top: undefined
                anchors.left: label.parent.left
            }

            PropertyChanges {
                target: label
                horizontalAlignment: Text.AlignHCenter
                visible: showLauncherNames
                elide: Text.ElideNone
            }
        }
    ]

    function addLauncher()
    {
        logic.addLauncher(isPopupItem);
    }

    function editLauncher()
    {
        logic.editLauncher(url, itemIndex, isPopupItem);
    }

    function removeLauncher()
    {
        var m = isPopupItem ? popupModel : launcherModel;
        m.removeUrl(itemIndex);
    }
}
