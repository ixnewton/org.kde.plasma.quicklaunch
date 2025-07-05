/*
 *  SPDX-FileCopyrightText: 2015 David Rosca <nowrep@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick 2.2
import QtQuick.Layouts 1.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.draganddrop 2.0 as DragAndDrop
import org.kde.plasma.private.quicklaunch 1.0

import "layout.js" as LayoutManager

PlasmoidItem {
    id: root

    readonly property int maxSectionCount: plasmoid.configuration.maxSectionCount
    readonly property bool showLauncherNames : plasmoid.configuration.showLauncherNames
    readonly property bool enablePopup : plasmoid.configuration.enablePopup
    readonly property string title : plasmoid.formFactor == PlasmaCore.Types.Planar ? plasmoid.configuration.title : ""
    readonly property bool onLeftOrRightPanel: plasmoid.location === PlasmaCore.Types.LeftEdge || plasmoid.location === PlasmaCore.Types.RightEdge
    property bool vertical: plasmoid.formFactor == PlasmaCore.Types.Vertical || (plasmoid.formFactor == PlasmaCore.Types.Planar && plasmoid.height > plasmoid.width)
    property bool horizontal: !vertical
    
    // Plasma theme detection for popup background using Kirigami.Theme
    // Expose theme properties for popup use
    readonly property color themeBackgroundColor: Kirigami.Theme.backgroundColor
    readonly property color themeTextColor: Kirigami.Theme.textColor
    readonly property color themeHighlightColor: Kirigami.Theme.highlightColor
    readonly property color themeButtonBackgroundColor: Kirigami.Theme.alternateBackgroundColor
    readonly property string themeColorScheme: Kirigami.Theme.colorSet
    readonly property bool themeDarkMode: Kirigami.Theme.colorSet === Kirigami.Theme.Complementary
    
    // Debug: Alternative approach to detect SVG background themes
    // Note: Direct SVG access not available, using Dialog properties instead
    property bool dragging : false
    property bool suspendPopupClosing: false
    
    // Timer to lock popup open for 3 seconds during drag operations
    Timer {
        id: popupLockTimer
        interval: 3000  // 3 seconds
        repeat: false
        onTriggered: {
            suspendPopupClosing = false;
        }
    }
    
    // Internal drag tracking (same as popup)
    property bool internalDragActive: false
    property int internalDragSourceIndex: -1
    
    // Drag operations logging disabled
    function logDragState(message) {
        // Debug logging disabled
        // console.log(`[MAIN-DRAG] ${message} -`,
        //           `dragActive:${internalDragActive},`,
        //           `sourceIndex:${internalDragSourceIndex},`,
        //           `popupActive:${popup ? popup.visible : 'no popup'}`);
    }

    readonly property bool onTopOrBottomPanel: horizontal && (plasmoid.location == PlasmaCore.Types.TopEdge || plasmoid.location == PlasmaCore.Types.BottomEdge)

    Layout.minimumWidth: LayoutManager.minimumWidth()
    Layout.minimumHeight: LayoutManager.minimumHeight()
    Layout.preferredWidth: LayoutManager.preferredWidth()
    Layout.preferredHeight: LayoutManager.preferredHeight()

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    Item {
        anchors.fill: parent

        DragAndDrop.DropArea {
            anchors.fill: parent
            preventStealing: true
            enabled: !plasmoid.immutable

            onDragEnter: function(event) {
                // Check for internal drag using same logic as popup
                var isInternal = isInternalDrop(event);
                
                // console.log("[DEBUG] Main widget onDragEnter - isInternal:", isInternal, "hasUrls:", event.mimeData.hasUrls, "internalDragActive:", internalDragActive, "sourceIndex:", internalDragSourceIndex);
                
                if (isInternal || event.mimeData.hasUrls || root.childAt(event.x, event.y) == popupArrow) {
                    dragging = true;
                    // Start 3-second timer to lock popup open
                    suspendPopupClosing = true;
                    popupLockTimer.restart();
                    // console.log("[DEBUG] Main widget drag accepted - dragging:", dragging);
                } else {
                    // console.log("[DEBUG] Main widget drag ignored");
                    event.ignore();
                }
            }

            onDragMove: function(event) {
                if (!event || !event.mimeData) {
                    // console.error("Invalid drag move event");
                    return;
                }
                
                // Ensure dragging state is maintained
                dragging = true;
                
                try {
                    // Show popup when dragging over arrow or when dragging external URLs
                    var targetItem = root.childAt(event.x, event.y);
                    var shouldShowPopup = (targetItem == popupArrow) || 
                                       (event.mimeData.hasUrls && !internalDragActive);
                    
                    if (shouldShowPopup) {
                        if (popup && !popup.visible) {
                            // Open popup the same way as clicking the arrow
                            if (popupArrowMouseArea && typeof popupArrowMouseArea.togglePopup === 'function') {
                                popupArrowMouseArea.togglePopup();
                            }
                        }
                        // Restart timer to keep popup locked for external drags
                        if (event.mimeData.hasUrls && !internalDragActive) {
                            suspendPopupClosing = true;
                            if (popupLockTimer) {
                                popupLockTimer.restart();
                            }
                        }
                        if (event.accept) {
                            event.accept();
                        }
                    }
                } catch (e) {
                    // console.error("Error in dragMove handler:", e);
                }
            }

            onDragLeave: function(event) {
                // Don't reset dragging state on drag leave - let timer handle it
                // This prevents popup from closing when moving between main area and popup
                launcherModel.clearDropMarker();
            }

            onDrop: function(event) {
                if (!event) {
                    // console.error("Drop event is undefined");
                    return;
                }
                
                dragging = false;
                // Stop timer and immediately resume normal popup closing
                popupLockTimer.stop();
                suspendPopupClosing = false;

                // console.log("Main widget drop - popup visible:", popup.visible, "drop coordinates:", event.x, event.y);
                
                // If popup is visible and drop is over popup area, let popup handle it
                if (popup.visible && popup.contains(Qt.point(event.x - popup.x, event.y - popup.y))) {
                    // console.log("Drop is over popup area - letting popup handle it");
                    event.ignore(); // Let the popup's drop handler take over
                    return;
                }

                if (event.mimeData.hasUrls && !isInternalDrop(event)) {
                    // console.log("[DEBUG] Main widget handling external URL drop");
                    
                    // In popup mode, always replace the first item
                    if (enablePopup && launcherModel.count > 0) {
                        // Replace the first URL
                        if (event.mimeData.urls.length > 0) {
                            // Remove the first item
                            launcherModel.removeUrl(0);
                            // Insert the new URL at the beginning
                            launcherModel.insertUrl(0, event.mimeData.urls[0]);
                            // Save configuration
                            saveConfiguration();
                        }
                    } else {
                        // Normal mode behavior - insert at drop position
                        var index = grid.indexAt(event.x, event.y);
                        if (index === -1) index = launcherModel.count;
                        launcherModel.insertUrls(index, event.mimeData.urls);
                    }
                    
                    // Show popup after dropping external URLs if not already visible
                    if (!popup.visible) {
                        popup.visible = true;
                    }
                    
                    // Ensure normal popup closing behavior is restored after drop
                    Qt.callLater(function() {
                        dragging = false;
                    });
                    return;
                }

                if (isInternalDrop(event)) {
                    // Check if this is a cross-widget drag (from popup to main)
                    const isFromPopup = event.mimeData.source && event.mimeData.source.isPopupItem === true;
                    const sourceIndex = isFromPopup ? 
                        (event.mimeData.source ? event.mimeData.source.itemIndex : -1) :
                        (internalDragSourceIndex >= 0 ? internalDragSourceIndex : -1);
                        
                    let targetIndex = grid.indexAt(event.x, event.y);
                    if (targetIndex === -1) targetIndex = launcherModel.count;
                    
                    logDragState(`Internal drop - isFromPopup:${isFromPopup}, sourceIndex:${sourceIndex}, targetIndex:${targetIndex}`);
                    
                    if (isFromPopup) {
                        // Handle drop from popup to main widget
                        if (popup && popup.popupModel && sourceIndex >= 0 && sourceIndex < popup.popupModel.count) {
                            // Get the URL from popup
                            const popupUrls = popup.popupModel.urls();
                            const url = popupUrls[sourceIndex];
                            
                            // console.log(`[MAIN-DRAG] Moving item from popup[${sourceIndex}] to main[${targetIndex}]: ${url}`);
                            
                            // Add to main widget
                            launcherModel.insertUrl(targetIndex, url);
                            
                            // Remove from popup and update configuration
                            popup.popupModel.removeUrl(sourceIndex);
                            
                            // Force update the popup display
                            if (popup.listView && popup.listView.model) {
                                popup.listView.model.urlsChanged();
                            }
                            
                            // Save configurations
                            saveConfiguration();
                            if (popup.saveConfiguration) {
                                popup.saveConfiguration();
                            }
                            
<<<<<<< HEAD
                            // console.log('[MAIN-DRAG] Item moved from popup to main widget');
=======
                            // Ensure popup URLs are updated immediately
                            plasmoid.configuration.popupUrls = popup.popupModel.urls();
                            
                            console.log('[MAIN-DRAG] Item moved from popup to main widget');
>>>>>>> 70e8766 (fix: handle drag state cleanup and improve popup drag-and-drop reliability in quicklaunch widget)
                        }
                    } else {
                        // Handle internal reordering within main widget
                        if (sourceIndex >= 0 && sourceIndex < launcherModel.count) {
                            // Get the URL being moved
                            const urlsArray = launcherModel.urls();
                            const url = urlsArray[sourceIndex];
                            
                            // console.log(`[MAIN-DRAG] Reordering main widget: ${sourceIndex} -> ${targetIndex}`);
                            
                            // Remove from original position
                            launcherModel.removeUrl(sourceIndex);
                            
                            // Adjust target index if removing from before target
                            let adjustedTargetIndex = targetIndex;
                            if (sourceIndex < targetIndex) {
                                adjustedTargetIndex = targetIndex - 1;
                            }
                            
                            // Insert at new position
                            launcherModel.insertUrl(adjustedTargetIndex, url);
                            
                            // Update configuration
                            saveConfiguration();
                            
                            // console.log('[MAIN-DRAG] Main widget reordered');
                        } else {
                            // console.error(`[MAIN-DRAG] Invalid sourceIndex: ${sourceIndex}, count: ${launcherModel.count}`);
                        }
                    }
                    
                    // Reset internal drag flags if this was a main widget drag
                    if (!isFromPopup) {
                        internalDragActive = false;
                        internalDragSourceIndex = -1;
                        // console.log('[MAIN-DRAG] Reset main widget drag state');
                    }
                    
                    event.accept(Qt.IgnoreAction);
                }
                
                // Reset drag state
                dragging = false;
            }
        }

        PlasmaComponents3.Label {
            id: titleLabel

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            height: Kirigami.Units.iconSizes.sizeForLabels
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            elide: Text.ElideMiddle
            text: title
            textFormat: Text.PlainText
        }

        Item {
            id: launcher

            anchors {
                top: title.length ? titleLabel.bottom : parent.top
                left: parent.left
                right: !vertical && popupArrow.visible ? popupArrow.left : parent.right
                bottom: vertical && popupArrow.visible ? popupArrow.top : parent.bottom
            }

            GridView {
                id: grid
                objectName: "quickLaunchGrid"
                anchors.fill: parent
                interactive: false
                flow: horizontal ? GridView.FlowTopToBottom : GridView.FlowLeftToRight
                cellWidth: LayoutManager.preferredCellWidth()
                cellHeight: LayoutManager.preferredCellHeight()
                visible: count

                onCurrentIndexChanged: {
                    // console.log("[DEBUG] Main GridView currentIndex changed to:", currentIndex);
                }

                onFocusChanged: {
                    // console.log("[DEBUG] Main GridView focus changed to:", focus);
                }

                model: ListModel {
                    id: displayModel
                    
                    Component.onCompleted: {
                        updateDisplay();
                    }
                    
                    function updateDisplay() {
                        clear();
                        if (enablePopup && launcherModel.count > 0) {
                            var urls = launcherModel.urls();
                            if (urls.length > 0) {
                                append({"url": urls[0]});
                            }
                        } else {
                            // In normal mode, show all items
                            var allUrls = launcherModel.urls();
                            for (var i = 0; i < allUrls.length; i++) {
                                append({"url": allUrls[i]});
                            }
                        }
                    }
                    
                    // Source model is launcherModel
                    property var sourceModel: UrlModel {
                        id: launcherModel
                        onCountChanged: displayModel.updateDisplay()
                        onDataChanged: displayModel.updateDisplay()
                    }
                    
                    // Update the display model based on the source model
                    // This is handled by the updateDisplay function above
                }

                delegate: IconItem { }

                function moveItemToPopup(iconItem, url) {
                    if (!popupArrow.visible) {
                        return;
                    }

                    popup.visible = true;
                    popup.mainItem.popupModel.insertUrl(popup.mainItem.popupModel.count, url);
                    popup.mainItem.listView.currentIndex = popup.mainItem.popupModel.count - 1;
                    iconItem.removeLauncher();
                }
            }

            Kirigami.Icon {
                id: defaultIcon
                anchors.fill: parent
                source: "fork"
                visible: !grid.visible

                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: i18n("Quicklaunch")
                    subText: i18nc("@info", "Add launchers by Drag and Drop or by using the context menu.")
                    location: Plasmoid.location
                }
            }
        }

        PlasmaCore.Dialog {
            id: popup
            type: PlasmaCore.Dialog.PopupMenu
            flags: Qt.WindowStaysOnTopHint
            hideOnWindowDeactivate: !suspendPopupClosing
            
            // Ensure suspendPopupClosing is reset when popup becomes inactive
            onActiveChanged: {
                if (!active && !dragging) {
                    suspendPopupClosing = false;
                }
            }
            
            location: {
                switch (plasmoid.location) {
                    case PlasmaCore.Types.TopEdge: return PlasmaCore.Types.TopEdge;
                    case PlasmaCore.Types.LeftEdge: return PlasmaCore.Types.LeftEdge;
                    case PlasmaCore.Types.RightEdge: return PlasmaCore.Types.RightEdge;
                    default: return PlasmaCore.Types.BottomEdge;
                }
            }
            
            // This ensures the popup behaves the same whether opened by click or drag
            onVisibleChanged: {
                if (visible) {
                    // Position is handled automatically by PlasmaCore.Dialog
                    // No manual positioning needed
                    
                    // Debug: Show detected Plasma theme properties (commented out for clean output)
                    /*
                    // Theme debug logging disabled
                    // console.log("[THEME] Plasma Background Color:", root.themeBackgroundColor);
                    // console.log("[THEME] Plasma Text Color:", root.themeTextColor);
                    // console.log("[THEME] Plasma Highlight Color:", root.themeHighlightColor);
                    // console.log("[THEME] Plasma Button Background:", root.themeButtonBackgroundColor);
                    // console.log("[THEME] Color Scheme:", root.themeColorScheme);
                    // console.log("[THEME] Dark Mode:", root.themeDarkMode);
                    */
                    
                    // Debug: Show Plasma Dialog SVG background information
                    //console.log("[THEME] Dialog Type:", popup.type);
                    //console.log("[THEME] Dialog Location:", popup.location);
                    //console.log("[THEME] Dialog Flags:", popup.flags);
                    //if (popup.backgroundHints !== undefined) {
                    //    console.log("[THEME] Dialog Background Hints:", popup.backgroundHints);
                    //}
                    
                    // Try to access internal background SVG if available
                    //if (popup.children && popup.children.length > 0) {
                    //    for (var i = 0; i < popup.children.length; i++) {
                    //        var child = popup.children[i];
                    //        console.log("[THEME] Dialog Child", i, ":", child.toString());
                    //        if (child.imagePath !== undefined) {
                    //            console.log("[THEME] SVG Image Path:", child.imagePath);
                    //        }
                    //        if (child.prefix !== undefined) {
                    //            console.log("[THEME] SVG Prefix:", child.prefix);
                    //        }
                    //    }
                    //}
                    
                    // Debug: Show alternative SVG background information
                    //console.log("[THEME] === SVG Background Debug (Alternative Method) ===");
                    
                    // Show what we can detect from the Dialog itself
                    //console.log("[THEME] Dialog uses PopupMenu type - likely uses dialogs/background SVG");
                    //console.log("[THEME] Expected SVG paths:");
                    //console.log("[THEME]   - dialogs/background.svg (popup background)");
                    //console.log("[THEME]   - widgets/panel-background.svg (panel background)");
                    
                    // Try to detect theme information through available properties
                    //try {
                    //    // Check if we can access theme through global objects
                    //    if (typeof theme !== 'undefined') {
                    //        console.log("[THEME] Global theme object available:", theme);
                    //        if (theme.themeName) {
                    //            console.log("[THEME] Current theme name:", theme.themeName);
                    //        }
                    //    }
                        
                    //    // Check plasmoid theme information
                    //    if (plasmoid.theme) {
                    //        console.log("[THEME] Plasmoid theme available:", plasmoid.theme);
                    //    }
                        
                    //    // Show what type of background the dialog should be using
                    //    console.log("[THEME] Dialog type suggests SVG background:");
                    //    console.log("[THEME]   - Type:", popup.type, "(PopupMenu = themed background)");
                    //    console.log("[THEME]   - Location:", popup.location, "(affects SVG orientation)");
                        
                    //    // Estimate theme file locations based on common Plasma paths
                    //    console.log("[THEME] Likely SVG file locations:");
                    //    console.log("[THEME]   - ~/.local/share/plasma/desktoptheme/[theme]/dialogs/background.svg");
                    //    console.log("[THEME]   - /usr/share/plasma/desktoptheme/[theme]/dialogs/background.svg");
                        
                    //} catch (e) {
                    //    console.log("[THEME] Error accessing theme info:", e);
                    //}
                }
            }

            // Manual positioning is required to apply a pixel offset.
            // The 'location' and 'visualParent' properties do not support this.
            x: {
                if (!popup || !root || !root.width) return 0;
                
                if (root.onLeftOrRightPanel) {
                    if (plasmoid.location == PlasmaCore.Types.LeftEdge) {
                        // Position right of the panel, with a 10px margin
                        return root.mapToGlobal(root.width, 0).x + 10;
                    } else { // RightEdge
                        // Position left of the panel, with a 10px margin
                        // Use a default width if popup.width is not available yet
                        var popupWidth = (popup && popup.width) ? popup.width : 200; // Default width if not available
                        return root.mapToGlobal(0, 0).x - popupWidth - 10;
                    }
                }
                
                // Default for top/bottom panels
                if (!popupArrow || !popupArrow.width) return 0;
                
                var arrowGlobalX = root.mapToGlobal(popupArrow.x, 0).x;
                var popupWidth = popup.width || 200; // Default width if not available
                var centeredX = arrowGlobalX + (popupArrow.width / 2) - (popupWidth / 2);
                var screenWidth = plasmoid.screenGeometry ? plasmoid.screenGeometry.width : 800; // Fallback width

                if (centeredX < 8) {
                    return 8;
                } else if (centeredX + popupWidth > screenWidth - 8) {
                    return screenWidth - popupWidth - 8;
                } else {
                    return centeredX;
                }
            }
            y: {
                if (root.onTopOrBottomPanel) {
                    if (plasmoid.location == PlasmaCore.Types.TopEdge) {
                        // Position below the panel, accounting for panel height and margin
                        return root.mapToGlobal(0, root.height).y + plasmoid.configuration.popupVerticalOffset + 10;
                    } else { // BottomEdge
                        // Position above the panel, accounting for panel height, popup height and margin
                        return root.mapToGlobal(0, 0).y - popup.height - plasmoid.configuration.popupVerticalOffset - 10;
                    }
                }

                // Default behavior for vertical panels or desktop
                return root.mapToGlobal(0, vertical ? (popupArrow.y - height) : 0).y;
            }

            mainItem: Item {
                id: popupContainer
                width: popupContent.width
                height: popupContent.height

                Popup {
                    id: popupContent
                    anchors.centerIn: parent
                    Keys.onEscapePressed: popup.visible = false
                }
            }
        }

        PlasmaCore.ToolTipArea {
            id: popupArrow
            visible: enablePopup
            location: Plasmoid.location

            anchors {
                top: vertical ? undefined : parent.top
                right: parent.right
                bottom: parent.bottom
            }

            subText: popup.visible ? i18n("Hide icons") : i18n("Show hidden icons")

            MouseArea {
                id: popupArrowMouseArea
                anchors.fill: parent
                hoverEnabled: true
                
                function togglePopup() {
                    popup.visible = !popup.visible;
                    // Position is handled automatically by PlasmaCore.Dialog
                }
                
                onClicked: togglePopup()
                
                Keys.onPressed: {
                    switch (event.key) {
                    case Qt.Key_Space:
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                    case Qt.Key_Select:
                        popupArrowMouseArea.clicked(null);
                        break;
                    }
                }
                Accessible.name: parent.subText
                Accessible.role: Accessible.Button

                Kirigami.Icon {
                    anchors.fill: parent

                    rotation: popup.visible ? 180 : 0
                    Behavior on rotation {
                        RotationAnimation {
                            duration: Kirigami.Units.shortDuration * 3
                        }
                    }

                    source: {
                        if (plasmoid.location == PlasmaCore.Types.TopEdge) {
                            return "arrow-down";
                        } else if (plasmoid.location == PlasmaCore.Types.LeftEdge) {
                            return "arrow-right";
                        } else if (plasmoid.location == PlasmaCore.Types.RightEdge) {
                            return "arrow-left";
                        } else if (vertical) {
                            return "arrow-right";
                        } else {
                            return "arrow-up";
                        }
                    }
                }
            }
        }
    }

    Logic {
        id: logic

        onLauncherAdded: {
            var m = isPopup ? popup.mainItem.popupModel : launcherModel;
            m.appendUrl(url);
        }

        onLauncherEdited: {
            var m = isPopup ? popup.mainItem.popupModel : launcherModel;
            m.changeUrl(index, url);
        }
    }

    // States to fix binding loop with enabled popup
    states: [
        State {
            name: "normal"
            when: !vertical

            PropertyChanges {
                target: popupArrow
                width: Kirigami.Units.iconSizes.smallMedium
                height: root.height
            }
        },

        State {
            name: "vertical"
            when: vertical

            PropertyChanges {
                target: popupArrow
                width: root.width
                height: Kirigami.Units.iconSizes.smallMedium
            }
        }
    ]

    Connections {
        target: plasmoid.configuration
        function onLauncherUrlsChanged() {
            displayModel.sourceModel.urlsChanged.disconnect(saveConfiguration);
            displayModel.sourceModel.setUrls(plasmoid.configuration.launcherUrls);
            displayModel.sourceModel.urlsChanged.connect(saveConfiguration);
            // Update the display model
            displayModel.updateDisplay();
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action", "Add Launcher…")
            icon.name: "list-add"
            onTriggered: logic.addLauncher()
        }
    ]

    Component.onCompleted: {
        // Initialize the source model with launcher URLs
        displayModel.sourceModel.setUrls(plasmoid.configuration.launcherUrls);
        displayModel.sourceModel.urlsChanged.connect(saveConfiguration);
        // Update the display model
        displayModel.updateDisplay();
    }

    function saveConfiguration()
    {
        // Always save the full launcher model, not the display model
        plasmoid.configuration.launcherUrls = displayModel.sourceModel.urls();
        
        // Only save popup URLs if popup model exists
        if (typeof popup !== 'undefined' && popup.popupModel) {
            plasmoid.configuration.popupUrls = popup.popupModel.urls();
        }
    }
    
    function isInternalDrop(event)
    {
        // Check global internal drag flag first
        if (internalDragActive && internalDragSourceIndex >= 0) {
            return true;
        }
        
        // Fallback: Check if source is an IconItem with itemIndex (internal drag)
        if (event.mimeData.source) {
            // Check if it's an IconItem with itemIndex (internal drag)
            if (event.mimeData.source.itemIndex !== undefined) {
                return true;
            }
            
            // Alternative check: if it has GridView property pointing to our grid
            if (event.mimeData.source.GridView && event.mimeData.source.GridView.view == grid) {
                return true;
            }
        }
        
        return false;
    }
}
