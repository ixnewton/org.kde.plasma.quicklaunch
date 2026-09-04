cmake_minimum_required(VERSION 3.16)

set(PROJECT_VERSION "6.5.80")
project(org.kde.plasma.quicklaunch VERSION ${PROJECT_VERSION})

set(QT_MIN_VERSION "6.9.0")
set(KF6_MIN_VERSION "6.5.0")
set(PLASMA_MIN_VERSION "6.5.0")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FeatureSummary)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED
    Core
    Gui
    DBus
    Network
    Quick
    Qml
    Widgets
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Config
    CoreAddons
    I18n
    KIO
    Service
    IconThemes
    JobWidgets
)

find_package(Plasma ${PLASMA_MIN_VERSION} REQUIRED)
find_package(PlasmaQuick ${PLASMA_MIN_VERSION} REQUIRED)

# Copy metadata.json to build directory for K_PLUGIN_CLASS_WITH_JSON
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/metadata.json ${CMAKE_CURRENT_BINARY_DIR}/metadata.json COPYONLY)

plasma_add_applet(org.kde.plasma.quicklaunch
    QML_SOURCES
        ConfigGeneral.qml
        config.qml
        IconItem.qml
        main.qml
        Popup.qml
        QuicklaunchPopup.qml
        UrlModel.qml
        layout.js
    CPP_SOURCES
        quicklaunch_p.cpp
    RESOURCES
        main.xml
    GENERATE_APPLET_CLASS
)

target_link_libraries(org.kde.plasma.quicklaunch PRIVATE KF6::KIOWidgets KF6::JobWidgets)

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
