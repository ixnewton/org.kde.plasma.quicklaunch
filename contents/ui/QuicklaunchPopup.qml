/*
 *  SPDX-FileCopyrightText: 2015 David Rosca <nowrep@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick 2.2

import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.extras 2.0 as PlasmaExtras

import org.kde.draganddrop 2.0 as DragAndDrop

import "layout.js" as LayoutManager

Item {
    id: popup

    property alias popupModel : popupModel
    property alias listView: listView
    property bool internalDragActive: false
    property int internalDragSourceIndex: -1
    
    // Debug function for drag operations (disabled)
    function logDragState(message) {
        // Debug logging disabled
        // console.log(`[POPUP-DRAG] ${message} -`,
        //           `dragActive:${internalDragActive},`,
        //           `sourceIndex:${internalDragSourceIndex},`,
        //           `itemCount:${popupModel ? popupModel.count : 0}`);
    }

    width: LayoutManager.popupItemWidth()
    height: Math.max(1, popupModel.count) * LayoutManager.popupItemHeight()
    
    // Translucent dialog-style background with proper rounded corners
    Rectangle {
        id: popupBackground
        anchors.fill: parent
        
        // Mimic translucent dialog background appearance
        color: {
            // Access theme properties from parent (main widget)
            var mainWidget = parent;
            while (mainWidget && !mainWidget.themeBackgroundColor) {
                mainWidget = mainWidget.parent;
            }
            return mainWidget ? mainWidget.themeBackgroundColor : PlasmaCore.Theme.backgroundColor;
        }
        
        // Translucent appearance like translucent/dialogs/background.svgz
        opacity: 0.85  // More translucent to match the SVG style
        radius: 6      // Slightly larger radius for modern appearance
        
        // Subtle border to match dialog appearance
        border.width: 1
        border.color: {
            var mainWidget = parent;
            while (mainWidget && !mainWidget.themeTextColor) {
                mainWidget = mainWidget.parent;
            }
            if (mainWidget && mainWidget.themeTextColor) {
                return Qt.rgba(mainWidget.themeTextColor.r, mainWidget.themeTextColor.g, mainWidget.themeTextColor.b, 0.15);
            }
            return Qt.rgba(1, 1, 1, 0.15); // Fallback to semi-transparent white
        }
        
        // Debug: Log the background approach being used
        Component.onCompleted: {
            console.log("[THEME] Using translucent dialog-style Rectangle background");
            console.log("[THEME] Mimicking: translucent/dialogs/background.svgz appearance");
            console.log("[THEME] Background color:", color);
            console.log("[THEME] Opacity:", opacity);
            console.log("[THEME] Radius:", radius);
        }
    }

    DragAndDrop.DropArea {
        id: dropArea
        anchors.fill: parent
        preventStealing: true
        enabled: !plasmoid.immutable

        onDragEnter: function(event) {
            // Access main widget through proper parent chain
            var mainWidget = parent;
            while (mainWidget && !mainWidget.popupLockTimer) {
                mainWidget = mainWidget.parent;
            }
            if (mainWidget && mainWidget.popupLockTimer) {
                mainWidget.popupLockTimer.restart();
                mainWidget.suspendPopupClosing = true;
            }
            event.accept(Qt.CopyAction);
        }

        onDragMove: function(event) {
            if (!event.mimeData.hasUrls) {
                return;
            }
            
            // Access main widget through proper parent chain
            var mainWidget = parent;
            while (mainWidget && !mainWidget.popupLockTimer) {
                mainWidget = mainWidget.parent;
            }
            if (mainWidget && mainWidget.popupLockTimer) {
                mainWidget.popupLockTimer.restart();
                mainWidget.suspendPopupClosing = true;
            }
            
            // Accept the drag to keep it going
            event.accept(Qt.CopyAction);
        }

        onDragLeave: function(event) {
            // Don't reset popup closing here - let timer handle it
            // This prevents popup from closing when moving within popup area
        }

        onDrop: function(event) {
            // Stop timer and immediately resume normal popup closing
            var mainWidget = parent;
            while (mainWidget && !mainWidget.popupLockTimer) {
                mainWidget = mainWidget.parent;
            }
            if (mainWidget && mainWidget.popupLockTimer) {
                mainWidget.popupLockTimer.stop();
                mainWidget.suspendPopupClosing = false;
            }

            // Check if this is a cross-widget drag (from main to popup)
            const isFromMain = event.mimeData.source && event.mimeData.source.isPopupItem === false;
            let sourceIndex = -1;
            
            if (isFromMain) {
                // Handle drag from main widget to popup
                sourceIndex = event.mimeData.source ? event.mimeData.source.itemIndex : -1;
                const targetIndex = listView.indexAt(event.x, event.y) !== -1 ? 
                                   listView.indexAt(event.x, event.y) : popupModel.count;
                
                logDragState(`Drop from main[${sourceIndex}] to popup[${targetIndex}]`);
                
                if (mainWidget && mainWidget.launcherModel && sourceIndex >= 0 && sourceIndex < mainWidget.launcherModel.count) {
                    // Get the URL from main widget
                    const mainUrls = mainWidget.launcherModel.urls();
                    const url = mainUrls[sourceIndex];
                    
                    console.log(`[POPUP-DRAG] Moving item from main[${sourceIndex}] to popup[${targetIndex}]: ${url}`);
                    
                    // Add to popup
                    popupModel.insertUrl(targetIndex, url);
                    
                    // Remove from main widget
                    mainWidget.launcherModel.removeUrl(sourceIndex);
                    
                    // Save configurations
                    saveConfiguration();
                    if (mainWidget.saveConfiguration) {
                        mainWidget.saveConfiguration();
                    }
                    
                    console.log('[POPUP-DRAG] Item moved from main to popup');
                }
                
                event.accept(Qt.IgnoreAction);
            } else if (isInternalDrop(event)) {
                // Handle internal reordering within popup
                sourceIndex = internalDragSourceIndex >= 0 ? 
                    internalDragSourceIndex : 
                    (event.mimeData.source ? event.mimeData.source.itemIndex : -1);
                    
                let targetIndex = listView.indexAt(event.x, event.y);
                if (targetIndex === -1) targetIndex = popupModel.count;
                
                logDragState(`Internal reorder: ${sourceIndex} -> ${targetIndex}`);
                
                if (sourceIndex >= 0 && sourceIndex < popupModel.count) {
                    // Get the URL being moved
                    const urlsArray = popupModel.urls();
                    const url = urlsArray[sourceIndex];
                    
                    // Remove from original position
                    popupModel.removeUrl(sourceIndex);
                    
                    // Adjust target index if removing from before target
                    let adjustedTargetIndex = targetIndex;
                    if (sourceIndex < targetIndex) {
                        adjustedTargetIndex = targetIndex - 1;
                    }
                    
                    // Insert at new position
                    popupModel.insertUrl(adjustedTargetIndex, url);
                    
                    // Save configuration
                    saveConfiguration();
                    
                    console.log('[POPUP-DRAG] Popup reordered');
                }
                
                // Reset internal drag flags
                internalDragActive = false;
                internalDragSourceIndex = -1;
                
                event.accept(Qt.IgnoreAction);
            } else if (event.mimeData.hasUrls) {
                // Handle external URL drop
                console.log("[POPUP-DRAG] Processing external URL drop");
                const index = listView.indexAt(event.x, event.y);
                const targetIndex = index === -1 ? popupModel.count : index;
                
                popupModel.insertUrls(targetIndex, event.mimeData.urls);
                event.accept(event.proposedAction);
                
                // Save configuration
                saveConfiguration();
                
                console.log(`[POPUP-DRAG] URLs inserted at ${targetIndex}, new count:`, popupModel.count);
            } else {
                console.log("[POPUP-DRAG] Drop event not handled - no URLs or unrecognized format");
                event.ignore();
            }
        }
    }

    ListView {
        id: listView
        anchors.fill: parent

        focus: true
        interactive: true
        keyNavigationWraps: true
        
        // Empty state when no popup URLs exist
        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - (Kirigami.Units.largeSpacing * 4)
            visible: popupModel.count === 0
            text: i18n("No hidden launchers")
            helpfulAction: Kirigami.Action {
                text: i18n("Add Launcher")
                icon.name: "list-add"
                onTriggered: logic.addLauncher(true)
            }
            explanation: i18n("Drag and drop launchers here from the main widget or add them using the context menu.")
        }

        model: UrlModel {
            id: popupModel
        }

        delegate: IconItem {
            isPopupItem: true
        }

        highlight: PlasmaExtras.Highlight {}

        highlightMoveDuration: Kirigami.Units.longDuration
        highlightMoveVelocity: 1

        function moveItemToGrid(iconItem, url) {
            launcherModel.insertUrl(launcherModel.count, url);
            listView.currentIndex = launcherModel.count - 1;
            iconItem.removeLauncher();
        }
    }

    Connections {
        target: plasmoid.configuration
        function onPopupUrlsChanged() {
            popupModel.urlsChanged.disconnect(saveConfiguration);
            popupModel.setUrls(plasmoid.configuration.popupUrls);
            popupModel.urlsChanged.connect(saveConfiguration);
        }
    }

    Component.onCompleted: {
        popupModel.setUrls(plasmoid.configuration.popupUrls);
        popupModel.urlsChanged.connect(saveConfiguration);
    }

    function saveConfiguration()
    {
        plasmoid.configuration.popupUrls = popupModel.urls();
    }

    function isInternalDrop(event)
    {
        // Check global internal drag flag first
        if (internalDragActive && internalDragSourceIndex >= 0) {
            return true;
        }
        
        // Fallback: Check if source is an IconItem from our popup
        if (event.mimeData.source) {
            // Check if it's from our popup by checking the isPopupItem property
            return event.mimeData.source.isPopupItem === true;
        }
        
        return false;
    }
}
