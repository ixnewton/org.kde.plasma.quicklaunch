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
    readonly property bool openOnMouseOver : plasmoid.configuration.openOnMouseOver
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
    
    // Timer for mouse-over popup opening
    Timer {
        id: mouseOverTimer
        interval: 0  // No delay - popup opens immediately on mouse-over
        repeat: false
        onTriggered: {
            console.log("[MOUSE-OVER DEBUG] Timer triggered");
            console.log("[MOUSE-OVER DEBUG] openOnMouseOver:", openOnMouseOver);
            console.log("[MOUSE-OVER DEBUG] launcherModel.count:", launcherModel.count);
            if (openOnMouseOver && launcherModel.count > 0) {
                console.log("[MOUSE-OVER DEBUG] Opening popup");
                popup.visible = true;
                plasmoid.status = PlasmaCore.Types.ActiveStatus;
            } else {
                console.log("[MOUSE-OVER DEBUG] Not opening popup - conditions not met");
            }
        }
    }
    
    // Note: Continuous hover tracking across separate windows (popup vs main widget) 
    // is fundamentally limited in Qt/Plasma. The popup captures mouse events,
    // preventing real-time hover updates on the main widget.
    
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
                    // Stop mouse-over timer during drag operations
                    mouseOverTimer.stop();
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
                        plasmoid.status = PlasmaCore.Types.ActiveStatus;
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
                            
                            // Ensure popup URLs are updated immediately
                            plasmoid.configuration.popupUrls = popup.popupModel.urls();
                            
 //                           console.log('[MAIN-DRAG] Item moved from popup to main widget');
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

                    plasmoid.status = PlasmaCore.Types.ActiveStatus;
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
                    subText: i18nc("@info", "Add a launcher here. Drag and drop from your applications menu or by using the context menu. Enable popup mode in configuration for popup menu.")
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
            
            // Reset plasmoid status when popup closes through any mechanism
            onVisibleChanged: {
                if (!visible) {
                    plasmoid.status = PlasmaCore.Types.PassiveStatus;
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
            
            // visualParent removed to allow manual positioning control
            // visualParent: popupArrow
            
            // Position is handled automatically by PlasmaCore.Dialog
            // No manual positioning needed
            // Manual positioning is required to apply a pixel offset.
            // The 'location' and 'visualParent' properties do not support this.
            x: {
                if (!popup || !root || !root.width) return 0;
                
                if (root.onLeftOrRightPanel) {
                    if (plasmoid.location == PlasmaCore.Types.LeftEdge) {
                        // Position right of the panel, with an 8px offset, aligned with panel edge
                        return root.mapToGlobal(root.width, 0).x + 10;
                    } else { // RightEdge
                        // Position left of the panel, with an 8px offset, aligned with panel edge
                        // Use a default width if popup.width is not available yet
                        var popupWidth = (popup && popup.width) ? popup.width : 200; // No container margins needed
                        return root.mapToGlobal(0, 0).x - popupWidth - 10;
                    }
                }
                
                // Default for top/bottom panels
                if (!popupArrow || !popupArrow.width) return 0;
                
                var arrowGlobalX = root.mapToGlobal(popupArrow.x, 0).x;
                var popupWidth = popup.width || 200; // No container margins needed
                // Get screen width from QtQuick.Screen with fallback
                var screenWidth = 1920; // Default fallback width
                if (typeof Qt !== 'undefined' && Qt.application && Qt.application.screens && Qt.application.screens.length > 0) {
                    screenWidth = Qt.application.screens[0].width;
//                    console.log("Using screen width from QtQuick.Screen:", screenWidth);
                }
                
                // Debug output for screen geometry using QtQuick.Screen
//                console.log("Screen Geometry Debug:");
//                console.log("plasmoid.screenGeometry:", JSON.stringify(plasmoid.screenGeometry));
                
                // Using QtQuick.Screen
                if (typeof Qt !== 'undefined' && Qt.application && Qt.application.screens) {
                    console.log("\nAvailable Screens:");
//                    for (var i = 0; i < Qt.application.screens.length; i++) {
//                        var screen = Qt.application.screens[i];
//                        console.log(`Screen ${i}:`);
//                        console.log(`- name: ${screen.name}`);
//                        console.log(`- geometry: ${screen.width}x${screen.height}+${screen.virtualX}+${screen.virtualY}`);
//                        console.log(`- availableGeometry: ${screen.availableWidth}x${screen.availableHeight}+${screen.availableVirtualX}+${screen.availableVirtualY}`);
//                        console.log(`- devicePixelRatio: ${screen.devicePixelRatio}`);
//                        console.log(`- primaryOrientation: ${screen.primaryOrientation}`);
//                        console.log(`- orientation: ${screen.orientation}`);
//                        console.log(`- virtualGeometry: ${screen.virtualX},${screen.virtualY} ${screen.width}x${screen.height}`);
//                        console.log(`- virtualSize: ${screen.virtualWidth}x${screen.virtualHeight}`);
//                    }
                    
                    // Get screen containing the widget
                    var widgetScreen = Qt.application.screens[0]; // Default to first screen
                    for (var j = 0; j < Qt.application.screens.length; j++) {
                        var scr = Qt.application.screens[j];
                        if (scr.virtualX <= arrowGlobalX && arrowGlobalX <= (scr.virtualX + scr.width) &&
                            scr.virtualY <= 0 && 0 <= (scr.virtualY + scr.height)) {
                            widgetScreen = scr;
                            break;
                        }
                    }
//                    console.log("\nWidget Screen:", widgetScreen.name);
//                    console.log("- geometry:", widgetScreen.width, "x", widgetScreen.height, "+", widgetScreen.virtualX, "+", widgetScreen.virtualY);
//                    console.log("- availableGeometry:", widgetScreen.availableWidth, "x", widgetScreen.availableHeight, "+", widgetScreen.availableVirtualX, "+", widgetScreen.availableVirtualY);
                } else {
//                    console.log("Qt.application.screens not available");
                }
                
                // Edge-aligned positioning based on widget position and available space
                var widgetLeftX = root.mapToGlobal(0, 0).x;
                var widgetRightX = root.mapToGlobal(root.width, 0).x;
                var widgetCenterX = root.mapToGlobal(root.width / 2, 0).x;
                var screenHalf = screenWidth / 2;
                
                                
                if (widgetCenterX < screenHalf) {
                    // Left-positioned widget logic
                    if (widgetRightX > popupWidth + 10) {
                        // Align menu at 4/5 width point of widget
                        var fourFifthsPos = widgetLeftX + (root.width * 4/5) - (popupWidth / 2);
                        return fourFifthsPos;
                    } else {
                        // Fall back to left screen edge alignment
                        var leftPos = 10;
                        return leftPos;
                    }
                } else {
                    // Right-positioned widget logic
                    if (screenWidth - widgetLeftX > popupWidth + 10) {
                        // Align menu at 4/5 width point of widget
                        var fourFifthsPos = widgetLeftX + (root.width * 4/5) - (popupWidth / 2);
                        return fourFifthsPos;
                    } else {
                        // Fall back to right screen edge alignment
                        var rightPos = screenWidth - 10 - popupWidth;
                        return rightPos;
                    }
                }
            }
            y: {
                if (root.onTopOrBottomPanel) {
                    if (plasmoid.location == PlasmaCore.Types.TopEdge) {
                        // Position below the panel with 10px offset
                        return root.mapToGlobal(0, root.height).y + plasmoid.configuration.popupVerticalOffset + 10;
                    } else { // BottomEdge
                        // Position above the panel, margins handle the offset
                        return root.mapToGlobal(0, 0).y - popup.height - plasmoid.configuration.popupVerticalOffset;
                    }
                }

                // Default behavior for vertical panels or desktop
                return root.mapToGlobal(0, vertical ? (popupArrow.y - height) : 0).y;
            }

            mainItem: Popup {
                id: popupContent
                Keys.onEscapePressed: popup.visible = false
            }
        }

        PlasmaCore.ToolTipArea {
            id: popupArrow
            // Only show popup arrow if popup is enabled AND there are launcher URLs
            visible: enablePopup && launcherModel.count > 0
            location: Plasmoid.location

            anchors {
                top: vertical ? undefined : parent.top
                right: parent.right
                bottom: parent.bottom
            }

            subText: launcherModel.count > 0 ? 
                (popup.visible ? i18n("Hide icons") : i18n("Show hidden icons")) : 
                i18n("Add the first launcher to enable popup")

            MouseArea {
                id: popupArrowMouseArea
                anchors.fill: parent
                hoverEnabled: true
                
                function togglePopup() {
                    // Only allow toggling popup if there are launcher URLs
                    if (launcherModel.count > 0) {
                        // Set plasmoid status to prevent panel autohide before changing visibility
                        if (!popup.visible) {
                            plasmoid.status = PlasmaCore.Types.ActiveStatus;
                        } else {
                            plasmoid.status = PlasmaCore.Types.PassiveStatus;
                        }
                        popup.visible = !popup.visible;
                        // Position is handled automatically by PlasmaCore.Dialog
                    }
                }
                
                onClicked: togglePopup()
                
                onEntered: {
                    // Debug logging
                    console.log("[MOUSE-OVER DEBUG] onEntered triggered");
                    console.log("[MOUSE-OVER DEBUG] openOnMouseOver:", openOnMouseOver);
                    console.log("[MOUSE-OVER DEBUG] popup.visible:", popup.visible);
                    console.log("[MOUSE-OVER DEBUG] launcherModel.count:", launcherModel.count);
                    
                    // Start mouse-over timer if enabled and popup is not already visible
                    if (openOnMouseOver && !popup.visible) {
                        console.log("[MOUSE-OVER DEBUG] Starting mouseOverTimer");
                        mouseOverTimer.start();
                    } else {
                        console.log("[MOUSE-OVER DEBUG] Not starting timer - conditions not met");
                    }
                }
                
                onExited: {
                    // Stop the mouse-over timer when mouse leaves
                    mouseOverTimer.stop();
                }
                
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

                    active: popupArrowMouseArea.containsMouse || popup.visible
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
