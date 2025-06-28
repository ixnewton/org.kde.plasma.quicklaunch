/*
 *  SPDX-FileCopyrightText: 2024 Cascade <cascade@windsurf.ai>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick 2.2
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    implicitHeight: layout.implicitHeight
    
    ColumnLayout {
        id: layout
        width: parent.width
        
        Kirigami.FormLayout {
            Layout.fillWidth: true
            
            label: i18n("Maximum number of rows/columns in sections:")
            PlasmaComponents3.SpinBox {
                value: cfg_maxSectionCount
                onValueChanged: cfg_maxSectionCount = value
            }
            
            PlasmaComponents3.CheckBox {
                text: i18n("Show launcher names")
                checked: cfg_showLauncherNames
                onCheckedChanged: cfg_showLauncherNames = checked
            }
            
            PlasmaComponents3.CheckBox {
                id: enablePopupCheckbox
                text: i18n("Enable popup for hidden items")
                checked: cfg_enablePopup
                onCheckedChanged: cfg_enablePopup = checked
            }
            
            label: i18n("Title:")
            PlasmaComponents3.TextField {
                text: cfg_title
                onTextChanged: cfg_title = text
                placeholderText: i18n("Optional title for the applet")
            }
            
            Kirigami.Separator {
                Layout.fillWidth: true
                visible: enablePopupCheckbox.checked
            }
            
            label: i18n("Popup vertical offset:")
            PlasmaComponents3.SpinBox {
                visible: enablePopupCheckbox.checked
                value: cfg_popupVerticalOffset
                onValueChanged: cfg_popupVerticalOffset = value
                from: -200
                to: 200
            }
        }
    }
}
