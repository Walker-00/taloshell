import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true
    baseWidth: 780

    property bool applySuggestedTheme: false
    readonly property var style: Config.options.appearance.style

    function goTo(term) {
        const t = term.toLowerCase().trim();
        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                const child = rootItem.children[i];
                if (child.title && child.title.toLowerCase().includes(t)) return child;
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                const found = findTarget(rootItem.children[i]);
                if (found) return found;
            }
            return null;
        }
        const target = findTarget(mainLayout);
        if (target) page.contentY = Math.max(0, target.mapToItem(mainLayout, 0, 0).y);
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        spacing: 20

        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Cookie12Sided
            title: Translation.tr("Looks")

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("A look changes shapes, motion, borders, bar style, fonts and window decoration in one click. Colors stay with your theme.")
            }
            ConfigSwitch {
                buttonIcon: "palette"
                text: Translation.tr("Also apply the look's suggested theme")
                checked: page.applySuggestedTheme
                onCheckedChanged: page.applySuggestedTheme = checked
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: LookEngine.looks
                    delegate: LookCard {
                        required property var modelData
                        look: modelData
                        width: (parent.width - 24) / 4
                        selected: LookEngine.currentId === modelData.id
                        onClicked: LookEngine.apply(modelData.id, page.applySuggestedTheme)
                        altAction: () => { if (!modelData.builtin) LookEngine.remove(modelData.id) }
                        StyledToolTip {
                            text: modelData.builtin ? (modelData.suggestedTheme ? Translation.tr("Suggested theme: %1").arg(modelData.suggestedTheme) : modelData.name)
                                : Translation.tr("Your look · right-click to delete")
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "rounded_corner"
            shape: MaterialShape.Shape.Pill
            title: Translation.tr("Shape")
            GroupedList {
                ConfigSlider {
                    buttonIcon: "rounded_corner"
                    text: Translation.tr("Roundness")
                    from: 0; to: 2
                    stopIndicatorValues: [1]
                    value: page.style.roundingScale
                    onValueChanged: Config.options.appearance.style.roundingScale = Math.round(value * 20) / 20
                }
                ConfigSwitch {
                    buttonIcon: "capsule"
                    text: Translation.tr("Pill-shaped buttons & groups")
                    checked: page.style.pillShapes
                    onCheckedChanged: Config.options.appearance.style.pillShapes = checked
                }
                ConfigSlider {
                    buttonIcon: "density_medium"
                    text: Translation.tr("Density")
                    from: 0.8; to: 1.25
                    stopIndicatorValues: [1]
                    value: page.style.density
                    onValueChanged: Config.options.appearance.style.density = Math.round(value * 20) / 20
                }
                ConfigSlider {
                    buttonIcon: "format_size"
                    text: Translation.tr("Text size")
                    from: 0.8; to: 1.3
                    stopIndicatorValues: [1]
                    value: page.style.fontScale
                    onValueChanged: Config.options.appearance.style.fontScale = Math.round(value * 50) / 50
                }
            }
        }

        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.SoftBurst
            title: Translation.tr("Motion")
            GroupedList {
                ConfigSlider {
                    buttonIcon: "speed"
                    text: Translation.tr("Animation length")
                    from: 0; to: 2
                    stopIndicatorValues: [1]
                    value: page.style.animationSpeed
                    onValueChanged: Config.options.appearance.style.animationSpeed = Math.round(value * 20) / 20
                }
                ConfigSwitch {
                    buttonIcon: "waves"
                    text: Translation.tr("Expressive (springy) motion")
                    checked: page.style.expressiveMotion
                    onCheckedChanged: Config.options.appearance.style.expressiveMotion = checked
                }
            }
        }

        ContentSection {
            icon: "border_style"
            shape: MaterialShape.Shape.Square
            title: Translation.tr("Borders & depth")
            GroupedList {
                ConfigSpinBox {
                    icon: "line_weight"
                    text: Translation.tr("Outline width")
                    from: 0; to: 4; stepSize: 1
                    value: page.style.borderWidth
                    onValueChanged: Config.options.appearance.style.borderWidth = value
                }
                ConfigSelectionArray {
                    text: Translation.tr("Outline color")
                    icon: "format_color_fill"
                    currentValue: page.style.borderColor
                    onSelected: newValue => Config.options.appearance.style.borderColor = newValue
                    options: [
                        { displayName: Translation.tr("Subtle"), icon: "blur_on", value: "default" },
                        { displayName: Translation.tr("Outline"), icon: "border_outer", value: "outline" },
                        { displayName: Translation.tr("Accent"), icon: "colorize", value: "primary" },
                        { displayName: Translation.tr("Strong"), icon: "contrast", value: "onSurface" }
                    ]
                }
                ConfigSlider {
                    buttonIcon: "opacity"
                    text: Translation.tr("Outline opacity")
                    from: 0; to: 1
                    value: page.style.borderOpacity
                    onValueChanged: Config.options.appearance.style.borderOpacity = Math.round(value * 20) / 20
                }
                ConfigSwitch {
                    buttonIcon: "shadow"
                    text: Translation.tr("Shadows")
                    checked: page.style.shadows
                    onCheckedChanged: Config.options.appearance.style.shadows = checked
                }
                ConfigSlider {
                    buttonIcon: "gradient"
                    text: Translation.tr("Shadow strength")
                    enabled: page.style.shadows
                    from: 0; to: 2
                    stopIndicatorValues: [1]
                    value: page.style.shadowStrength
                    onValueChanged: Config.options.appearance.style.shadowStrength = Math.round(value * 20) / 20
                }
            }
        }

        ContentSection {
            icon: "save"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Save your look")
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Saves shape, motion, borders, transparency, fonts, bar style and window decoration (plus your current theme as its suggestion) to %1").arg(LookEngine.userDir)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialTextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Look name")
                }
                RippleButtonWithIcon {
                    materialIcon: "save"
                    mainText: Translation.tr("Save")
                    enabled: nameField.text.trim().length > 0
                    onClicked: {
                        LookEngine.saveCurrent(nameField.text.trim());
                        nameField.text = "";
                    }
                }
                RippleButtonWithIcon {
                    materialIcon: "folder_open"
                    mainText: Translation.tr("Folder")
                    onClicked: LookEngine.openUserFolder()
                }
            }
        }
    }
}
