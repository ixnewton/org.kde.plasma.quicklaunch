import QtQuick 2.15
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker

PlasmoidItem {
    id: root
    
    preferredRepresentation: fullRepresentation
    
    property bool vertical: plasmoid.formFactor == PlasmaCore.Types.Vertical || (plasmoid.formFactor == PlasmaCore.Types.Planar && plasmoid.height > plasmoid.width)
    property bool onLeftOrRightPanel: plasmoid.location === PlasmaCore.Types.LeftEdge || plasmoid.location === PlasmaCore.Types.RightEdge
    property bool onTopOrBottomPanel: !vertical && (plasmoid.location == PlasmaCore.Types.TopEdge || plasmoid.location == PlasmaCore.Types.BottomEdge)

    // System model for power/session actions
    Kicker.SystemModel {
        id: systemModel
    }

    // Main Panel Icon
    Item {
        anchors.fill: parent
        
        Kirigami.Icon {
            id: mainIcon
            anchors.fill: parent
            source: "system-shutdown"
            active: mouseArea.containsMouse
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                popup.visible = !popup.visible
            }
        }
    }

    // Popup Menu - exact quicklaunch positioning
    PlasmaCore.Dialog {
        id: popup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        
        location: {
            switch (plasmoid.location) {
                case PlasmaCore.Types.TopEdge: return PlasmaCore.Types.TopEdge;
                case PlasmaCore.Types.LeftEdge: return PlasmaCore.Types.LeftEdge;
                case PlasmaCore.Types.RightEdge: return PlasmaCore.Types.RightEdge;
                default: return PlasmaCore.Types.BottomEdge;
            }
        }
        
        // Exact quicklaunch positioning with adjustments
        x: {
            if (!popup || !root || !root.width) return 0;
            
            if (root.onLeftOrRightPanel) {
                if (plasmoid.location == PlasmaCore.Types.LeftEdge) {
                    // Position right of the panel, with a 10px margin
                    return root.mapToGlobal(root.width, 0).x + 10;
                } else { // RightEdge
                    // Position left of the panel, with a 10px margin
                    var popupWidth = popup.width || 200;
                    return root.mapToGlobal(0, 0).x - popupWidth - 10;
                }
            }
            
            // Default for top/bottom panels - reduce left by 4px
            return root.mapToGlobal(-4, 0).x;
        }
        y: {
            if (root.onTopOrBottomPanel) {
                if (plasmoid.location == PlasmaCore.Types.TopEdge) {
                    // Position below the panel, reduce top offset to 9px
                    return root.mapToGlobal(0, root.height).y + 18;
                } else { // BottomEdge
                    // Position above the panel, reduce top offset to 9px
                    return root.mapToGlobal(0, 0).y - popup.height + 8;
                }
            }

            // Default behavior for vertical panels or desktop
            return root.mapToGlobal(0, vertical ? (root.height - height)/2 : 0).y;
        }

        Item {
                id: popupContainer
                width: popupContent.width
                height: popupContent.height

                Item {
                    id: popupContent
                    anchors.centerIn: parent
                    
                    // Fixed dimensions with 25% width reduction
                    width: 188
                    height: systemModel.count * (Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing)
                    
                    ListView {
                        id: listView
                        anchors.fill: parent
                        model: systemModel
                        spacing: 0
                        delegate: Item {
                            id: iconItem
                            width: 188
                            height: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing
                            
                            Rectangle {
                                anchors.fill: parent
                                color: mouseArea.containsMouse ? Kirigami.Theme.hoverColor : "transparent"
                                opacity: mouseArea.containsMouse ? 0.7 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                                }
                                z: -1
                            }
                            
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing / 2
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                
                                Kirigami.Icon {
                                    id: icon
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                    }
                                    width: Kirigami.Units.iconSizes.medium
                                    height: Kirigami.Units.iconSizes.medium
                                    source: model.decoration
                                    active: mouseArea.containsMouse
                                }
                                
                                PlasmaComponents3.Label {
                                    id: label
                                    anchors {
                                        verticalCenter: icon.verticalCenter
                                        left: icon.right
                                        leftMargin: Kirigami.Units.smallSpacing
                                        right: parent.right
                                    }
                                    text: model.display || ""
                                    font.pointSize: 12
                                    elide: Text.ElideRight
                                }
                                
                                onClicked: {
                                    systemModel.trigger(index, "", null);
                                    popup.visible = false;
                                }
                            }
                        }
                    }
                }
            }
    }
}
