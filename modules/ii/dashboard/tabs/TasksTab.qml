pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.dashboard
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    property string search: ""
    property int expandedId: -1

    function matches(task) {
        const q = root.search.toLowerCase().trim();
        if (q.length === 0) return true;
        if (q.startsWith("#")) return (task.tags ?? []).some(t => t.toLowerCase().startsWith(q.slice(1)));
        return task.title.toLowerCase().includes(q) || (task.notes ?? "").toLowerCase().includes(q);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ===== Toolbar =====
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            ToolbarTextField {
                Layout.fillWidth: true
                Layout.fillHeight: false
                implicitHeight: 40
                placeholderText: Translation.tr("Filter tasks… (#tag)")
                onTextChanged: root.search = text
            }
            RippleButtonWithIcon {
                materialIcon: "view_week"
                mainText: Translation.tr("Column")
                onClicked: Kanban.addColumn(Translation.tr("New column"))
            }
            RippleButtonWithIcon {
                materialIcon: "playlist_add_check"
                mainText: Translation.tr("Import to-do")
                visible: Todo.list.length > 0
                onClicked: Kanban.importTodo()
            }
            RippleButtonWithIcon {
                materialIcon: "delete_sweep"
                mainText: Translation.tr("Clear done")
                onClicked: Kanban.clearDone()
            }
        }

        // ===== Board =====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Repeater {
                model: Kanban.columns
                delegate: DropArea {
                    id: column
                    required property var modelData
                    required property int index
                    readonly property var columnTasks: Kanban.tasks.filter(t => t.column === modelData.id && root.matches(t))
                        .sort((a, b) => (b.priority - a.priority) || ((a.due || "9999") < (b.due || "9999") ? -1 : 1) || a.id - b.id)
                    readonly property bool isDone: modelData.id === Kanban.doneColumn
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    keys: ["kanban-task"]
                    onDropped: drop => {
                        Kanban.moveTask(drop.source.taskId, column.modelData.id);
                        drop.accept();
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: column.containsDrag ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer1
                        border.width: column.containsDrag ? 2 : (Appearance.sizes.borderWidth > 1 ? Appearance.sizes.borderWidth : 0)
                        border.color: column.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            MaterialSymbol {
                                text: column.modelData.icon ?? "view_column"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colPrimary
                            }
                            TextInput {
                                id: columnName
                                Layout.fillWidth: true
                                text: column.modelData.name
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer1
                                selectByMouse: true
                                onEditingFinished: if (text.trim().length > 0 && text !== column.modelData.name) Kanban.renameColumn(column.modelData.id, text.trim())
                            }
                            Rectangle {
                                implicitWidth: Math.max(22, countText.implicitWidth + 10)
                                implicitHeight: 22
                                radius: Math.min(height / 2, Appearance.rounding.full)
                                color: Appearance.colors.colSecondaryContainer
                                StyledText {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: column.columnTasks.length
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }
                            RippleButton {
                                visible: Kanban.columns.length > 2 && column.index > 0 && !column.isDone
                                implicitWidth: 26
                                implicitHeight: 26
                                buttonRadius: Appearance.rounding.full
                                onClicked: Kanban.removeColumn(column.modelData.id)
                                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 16; color: Appearance.colors.colSubtext }
                                StyledToolTip { text: Translation.tr("Remove column (tasks move to the first column)") }
                            }
                        }

                        // Quick add
                        ToolbarTextField {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            implicitHeight: 36
                            visible: !column.isDone
                            placeholderText: Translation.tr("+ Add task")
                            onAccepted: {
                                Kanban.quickAdd(text, column.modelData.id);
                                text = "";
                            }
                        }

                        // Cards
                        StyledListView {
                            id: list
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 6
                            clip: true
                            model: column.columnTasks
                            delegate: taskCard
                        }

                        StyledText {
                            visible: column.columnTasks.length === 0
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 20
                            text: column.isDone ? Translation.tr("Nothing finished yet") : Translation.tr("Drop tasks here")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    Component {
        id: taskCard
        Item {
            id: cardRoot
            required property var modelData
            readonly property int taskId: modelData.id
            readonly property bool expanded: root.expandedId === modelData.id
            readonly property bool done: modelData.column === Kanban.doneColumn
            width: ListView.view.width
            height: card.implicitHeight

            Rectangle {
                id: card
                property int taskId: cardRoot.taskId
                width: cardRoot.width
                implicitHeight: cardLayout.implicitHeight + 20
                radius: Appearance.rounding.normal
                color: dragArea.drag.active ? Appearance.colors.colSurfaceContainerHighest
                    : dragArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                border.width: Kanban.isOverdue(cardRoot.modelData) ? 1 : 0
                border.color: Appearance.colors.colError
                opacity: cardRoot.done ? 0.7 : 1

                Drag.active: dragArea.drag.active
                Drag.keys: ["kanban-task"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
                Drag.source: card

                states: State {
                    when: dragArea.drag.active
                    ParentChange { target: card; parent: root }
                    PropertyChanges { target: card; z: 100; scale: 1.03 }
                }

                // Priority stripe
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
                    width: 4
                    radius: 2
                    color: Kanban.priorityColor(cardRoot.modelData.priority)
                    visible: cardRoot.modelData.priority > 0
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    drag.target: card
                    drag.threshold: 8
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    onClicked: root.expandedId = cardRoot.expanded ? -1 : cardRoot.taskId
                    onReleased: {
                        if (drag.active) card.Drag.drop();
                        card.x = 0;
                        card.y = 0;
                    }
                }

                ColumnLayout {
                    id: cardLayout
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 16 }
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        text: cardRoot.modelData.title
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.strikeout: cardRoot.done
                        color: Appearance.colors.colOnLayer2
                    }

                    // Meta row
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: cardRoot.modelData.due !== "" || (cardRoot.modelData.tags ?? []).length > 0
                        Rectangle {
                            visible: cardRoot.modelData.due !== ""
                            implicitHeight: 20
                            implicitWidth: dueRow.implicitWidth + 12
                            radius: Math.min(height / 2, Appearance.rounding.full)
                            color: Kanban.isOverdue(cardRoot.modelData) ? Appearance.colors.colErrorContainer : Appearance.colors.colSecondaryContainer
                            Row {
                                id: dueRow
                                anchors.centerIn: parent
                                spacing: 3
                                MaterialSymbol { text: "event"; iconSize: 13; color: Kanban.isOverdue(cardRoot.modelData) ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer }
                                StyledText { text: Kanban.formatDue(cardRoot.modelData); font.pixelSize: Appearance.font.pixelSize.smallest; color: Kanban.isOverdue(cardRoot.modelData) ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer }
                            }
                        }
                        Repeater {
                            model: cardRoot.modelData.tags ?? []
                            delegate: Rectangle {
                                required property string modelData
                                implicitHeight: 20
                                implicitWidth: tagText.implicitWidth + 12
                                radius: Math.min(height / 2, Appearance.rounding.full)
                                color: Appearance.colors.colTertiaryContainer
                                StyledText { id: tagText; anchors.centerIn: parent; text: `#${modelData}`; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colOnTertiaryContainer }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !cardRoot.expanded && (cardRoot.modelData.notes ?? "").length > 0
                        text: cardRoot.modelData.notes ?? ""
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    // Expanded editor
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: cardRoot.expanded
                        spacing: 6
                        MaterialTextArea {
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Notes")
                            text: cardRoot.modelData.notes ?? ""
                            onEditingFinished: if (text !== (cardRoot.modelData.notes ?? "")) Kanban.updateTask(cardRoot.taskId, { notes: text })
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: [
                                    { label: Translation.tr("Today"), days: 0 },
                                    { label: Translation.tr("Tmrw"), days: 1 },
                                    { label: Translation.tr("+1w"), days: 7 },
                                    { label: "✕", days: -1 },
                                ]
                                delegate: RippleButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 26
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: Appearance.colors.colLayer3
                                    onClicked: {
                                        if (modelData.days < 0) { Kanban.updateTask(cardRoot.taskId, { due: "" }); return; }
                                        const d = new Date();
                                        d.setDate(d.getDate() + modelData.days);
                                        Kanban.updateTask(cardRoot.taskId, { due: Qt.formatDate(d, "yyyy-MM-dd") });
                                    }
                                    contentItem: StyledText { anchors.centerIn: parent; text: parent.modelData.label; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colOnLayer2 }
                                }
                            }
                        }
                        MaterialTextField {
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Due: YYYY-MM-DD or YYYY-MM-DDTHH:MM")
                            text: cardRoot.modelData.due
                            onEditingFinished: {
                                const v = text.trim();
                                if (v === "" || /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?$/.test(v)) Kanban.updateTask(cardRoot.taskId, { due: v });
                            }
                        }
                        MaterialTextField {
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Tags, comma separated")
                            text: (cardRoot.modelData.tags ?? []).join(", ")
                            onEditingFinished: Kanban.updateTask(cardRoot.taskId, { tags: text.split(",").map(t => t.trim().replace(/^#/, "")).filter(t => t.length > 0) })
                        }
                    }

                    // Actions
                    RowLayout {
                        Layout.fillWidth: true
                        visible: dragArea.containsMouse || cardRoot.expanded
                        spacing: 2
                        Repeater {
                            model: [
                                { icon: "chevron_left", tip: Translation.tr("Move left"), action: () => Kanban.moveBy(cardRoot.taskId, -1) },
                                { icon: "flag", tip: Translation.tr("Priority: %1").arg(Kanban.priorities[cardRoot.modelData.priority].name), action: () => Kanban.cyclePriority(cardRoot.taskId) },
                                { icon: cardRoot.done ? "undo" : "check", tip: cardRoot.done ? Translation.tr("Reopen") : Translation.tr("Done"), action: () => Kanban.moveTask(cardRoot.taskId, cardRoot.done ? Kanban.columns[0].id : Kanban.doneColumn) },
                                { icon: "delete", tip: Translation.tr("Delete"), action: () => Kanban.removeTask(cardRoot.taskId) },
                                { icon: "chevron_right", tip: Translation.tr("Move right"), action: () => Kanban.moveBy(cardRoot.taskId, 1) },
                            ]
                            delegate: RippleButton {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 26
                                buttonRadius: Appearance.rounding.full
                                onClicked: modelData.action()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: parent.modelData.icon
                                    iconSize: 17
                                    fill: parent.modelData.icon === "flag" && cardRoot.modelData.priority > 0 ? 1 : 0
                                    color: parent.modelData.icon === "flag" ? Kanban.priorityColor(cardRoot.modelData.priority) : Appearance.colors.colOnLayer2
                                }
                                StyledToolTip { text: parent.modelData.tip }
                            }
                        }
                    }
                }
            }
        }
    }
}
