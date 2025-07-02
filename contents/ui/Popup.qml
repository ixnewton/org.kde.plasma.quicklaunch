/*
 *  SPDX-FileCopyrightText: 2015 David Rosca <nowrep@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick 2.2

import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.extras 2.0 as PlasmaExtras

import org.kde.draganddrop 2.0 as DragAndDrop

import "layout.js" as LayoutManager

Item {
    id: popup

    property alias popupModel : popupModel
    property alias listView: listView
    property bool internalDragActive: false
    property int internalDragSourceIndex: -1

    width: LayoutManager.popupItemWidth()
    height: Math.max(1, popupModel.count) * LayoutManager.popupItemHeight()

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

            if (isInternalDrop(event)) {
                // Use global sourceIndex if available, fallback to event source
                var sourceIndex = internalDragSourceIndex >= 0 ? internalDragSourceIndex : (event.mimeData.source ? event.mimeData.source.itemIndex : -1);
                var targetIndex = listView.indexAt(event.x, event.y);
                if (targetIndex === -1) targetIndex = popupModel.count;
                
                if (sourceIndex >= 0 && sourceIndex < popupModel.count) {
                    // Get the URL being moved
                    var urlsArray = popupModel.urls();
                    var url = urlsArray[sourceIndex];
                    
                    // Remove from original position first
                    popupModel.removeUrl(sourceIndex);
                    
                    // Adjust target index if removing from before target
                    var adjustedTargetIndex = targetIndex;
                    if (sourceIndex < targetIndex) {
                        adjustedTargetIndex = targetIndex - 1;
                    }
                    
                    // Insert at new position
                    popupModel.insertUrl(adjustedTargetIndex, url);
                    saveConfiguration();
                }
                
                // Reset internal drag flags
                internalDragActive = false;
                internalDragSourceIndex = -1;
                
                event.accept(Qt.IgnoreAction);
            } else if (event.mimeData.hasUrls) {
                console.log("Processing external URL drop");
                var index = listView.indexAt(event.x, event.y);
                
                popupModel.insertUrls(index == -1 ? popupModel.count : index, event.mimeData.urls);
                event.accept(event.proposedAction);
                console.log("URLs inserted, new count:", popupModel.count);
            } else {
                console.log("Drop event not handled - no URLs or unrecognized format");
                event.ignore();
            }
            
            // Save configuration after any drop operation
            saveConfiguration();
        }
    }

    ListView {
        id: listView
        anchors.fill: parent

        focus: true
        interactive: true
        keyNavigationWraps: true

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
            // Check if it's an IconItem with itemIndex (internal drag)
            if (event.mimeData.source.itemIndex !== undefined) {
                return true;
            }
            
            // Alternative check: if it has ListView property pointing to our listView
            if (event.mimeData.source.ListView && event.mimeData.source.ListView.view == listView) {
                return true;
            }
        }
        
        return false;
    }
}
