import QtQuick
import qs.modules.common

Rectangle {
    radius: Math.min(Math.min(width, height) / 2, Appearance.rounding.full)
}