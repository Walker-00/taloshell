import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Theme quick switcher: click = pick a theme in the launcher, scroll = cycle
// (favorites first if you have any), right click = light/dark.
RippleButton {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: isMaterial ? 32 : 22
    implicitHeight: implicitWidth
    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colTertiaryContainer : "transparent"
    colBackgroundHover: isMaterial ? Appearance.colors.colTertiaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active

    onPressed: TalosLauncher.toggle("themes")
    altAction: () => ThemeEngine.toggleDarkMode()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => ThemeEngine.cycle(wheel.angleDelta.y < 0 ? 1 : -1, ThemeEngine.favorites.length > 1)
    }

    // Tiny palette of the current colors
    Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: 2
        Repeater {
            model: [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.m3colors.m3tertiary, Appearance.colors.colOnLayer0]
            delegate: Rectangle {
                required property color modelData
                width: 6; height: 6
                radius: Math.min(width / 2, Appearance.rounding.full)
                color: modelData
            }
        }
    }
    StyledToolTip {
        text: (ThemeEngine.presetActive ? (ThemeEngine.currentTheme?.name ?? ThemeEngine.currentId) : Translation.tr("Wallpaper colors"))
            + "\n" + Translation.tr("Click: pick · Scroll: cycle · Right-click: light/dark")
    }
}
