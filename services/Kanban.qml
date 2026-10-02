pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/**
 * Kanban task board (inspired by Brain_Shell) with configurable columns,
 * priorities, due dates, tags and deadline reminders.
 * Stored in ~/.local/state/taloshell/user/kanban.json
 * IPC: qs -c taloshell ipc call kanban add "Buy milk"
 */
Singleton {
    id: root

    readonly property string filePath: FileUtils.trimFileProtocol(`${Directories.state}/user/kanban.json`)
    property bool loaded: false

    property list<var> columns: []
    property list<var> tasks: []
    property int nextId: 1
    property list<int> notifiedIds: []

    readonly property var defaultColumns: [
        { id: "todo", name: Translation.tr("To do"), icon: "radio_button_unchecked" },
        { id: "doing", name: Translation.tr("In progress"), icon: "pending" },
        { id: "done", name: Translation.tr("Done"), icon: "check_circle" },
    ]
    readonly property var priorities: [
        { value: 0, name: Translation.tr("None"), icon: "remove" },
        { value: 1, name: Translation.tr("Low"), icon: "keyboard_arrow_down" },
        { value: 2, name: Translation.tr("Medium"), icon: "drag_handle" },
        { value: 3, name: Translation.tr("High"), icon: "keyboard_arrow_up" },
        { value: 4, name: Translation.tr("Urgent"), icon: "priority_high" },
    ]

    readonly property string doneColumn: columns.length > 0 ? columns[columns.length - 1].id : "done"
    readonly property int openCount: tasks.filter(t => t.column !== root.doneColumn).length
    readonly property int overdueCount: tasks.filter(t => root.isOverdue(t)).length
    readonly property int dueTodayCount: tasks.filter(t => root.isDueToday(t) && t.column !== root.doneColumn).length

    function priorityColor(p) {
        switch (p) {
            case 4: return Appearance.colors.colError;
            case 3: return Appearance.m3colors.m3tertiary;
            case 2: return Appearance.colors.colPrimary;
            case 1: return Appearance.colors.colSecondary;
            default: return Appearance.colors.colOutlineVariant;
        }
    }

    function tasksIn(columnId) {
        return root.tasks
            .filter(t => t.column === columnId)
            .sort((a, b) => (b.priority - a.priority) || ((a.due || "9999") < (b.due || "9999") ? -1 : 1) || a.id - b.id);
    }

    // Date-only dues ("YYYY-MM-DD") are local days; new Date() would read them as UTC midnight
    function dueDate(task) {
        if (!task.due) return null;
        const m = task.due.match(/^(\d{4})-(\d{2})-(\d{2})$/);
        return m ? new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3])) : new Date(task.due);
    }
    function isOverdue(task) {
        const d = root.dueDate(task);
        if (d === null || task.column === root.doneColumn) return false;
        const deadline = task.due.length === 10 ? d.getTime() + 86400000 : d.getTime();
        return deadline < Date.now();
    }
    function isDueToday(task) {
        const d = root.dueDate(task);
        if (!d) return false;
        const now = new Date();
        return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
    }
    function formatDue(task) {
        const d = root.dueDate(task);
        if (!d) return "";
        const now = new Date();
        const days = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000);
        const time = task.due.length > 10 ? ` ${Qt.formatTime(d, "hh:mm")}` : "";
        if (days === 0) return Translation.tr("Today") + time;
        if (days === 1) return Translation.tr("Tomorrow") + time;
        if (days === -1) return Translation.tr("Yesterday") + time;
        if (days > 1 && days < 7) return Qt.locale().dayName(d.getDay(), Locale.ShortFormat) + time;
        return Qt.formatDate(d, "dd MMM") + time;
    }

    // ---- mutations ----
    function save() {
        fileView.setText(JSON.stringify({ columns: root.columns, tasks: root.tasks, nextId: root.nextId, notifiedIds: root.notifiedIds }, null, 2));
    }

    function addTask(columnId, title, options = {}) {
        const t = title.trim();
        if (t.length === 0) return -1;
        const task = {
            id: root.nextId,
            title: t,
            notes: options.notes ?? "",
            column: columnId || (root.columns[0]?.id ?? "todo"),
            priority: options.priority ?? 0,
            due: options.due ?? "",
            tags: options.tags ?? [],
            created: new Date().toISOString(),
        };
        root.nextId++;
        root.tasks = [...root.tasks, task];
        root.save();
        return task.id;
    }

    // Quick-add syntax: "Fix bug !3 @tomorrow #work"  (!0-4 priority, @today/@tomorrow/@YYYY-MM-DD, #tag)
    function quickAdd(text, columnId = "") {
        let title = text;
        const options = { tags: [] };
        const prio = title.match(/(^|\s)!([0-4])(?=\s|$)/);
        if (prio) { options.priority = parseInt(prio[2]); title = title.replace(prio[0], " "); }
        const due = title.match(/(^|\s)@(today|tomorrow|\d{4}-\d{2}-\d{2})(?=\s|$)/);
        if (due) {
            const d = new Date();
            if (due[2] === "tomorrow") d.setDate(d.getDate() + 1);
            options.due = due[2].length === 10 && due[2].includes("-") ? due[2] : Qt.formatDate(d, "yyyy-MM-dd");
            title = title.replace(due[0], " ");
        }
        for (const tag of title.match(/(^|\s)#([\w-]+)/g) ?? []) {
            options.tags.push(tag.trim().slice(1));
            title = title.replace(tag, " ");
        }
        return root.addTask(columnId, title.replace(/\s+/g, " "), options);
    }

    function updateTask(id, patch) {
        root.tasks = root.tasks.map(t => t.id === id ? Object.assign({}, t, patch) : t);
        if (patch.due !== undefined) root.notifiedIds = root.notifiedIds.filter(n => n !== id);
        root.save();
    }

    function moveTask(id, columnId) {
        const patch = { column: columnId };
        if (columnId === root.doneColumn) patch.completed = new Date().toISOString();
        root.updateTask(id, patch);
    }

    function moveBy(id, direction) {
        const task = root.tasks.find(t => t.id === id);
        if (!task) return;
        const i = root.columns.findIndex(c => c.id === task.column);
        const next = Math.max(0, Math.min(root.columns.length - 1, i + direction));
        if (next !== i) root.moveTask(id, root.columns[next].id);
    }

    function cyclePriority(id) {
        const task = root.tasks.find(t => t.id === id);
        if (task) root.updateTask(id, { priority: (task.priority + 1) % 5 });
    }

    function removeTask(id) {
        root.tasks = root.tasks.filter(t => t.id !== id);
        root.save();
    }

    function clearDone() {
        root.tasks = root.tasks.filter(t => t.column !== root.doneColumn);
        root.save();
    }

    function addColumn(name) {
        const id = name.toLowerCase().replace(/[^a-z0-9]+/g, "-") + "-" + Date.now().toString(36);
        root.columns = [...root.columns.slice(0, -1), { id: id, name: name, icon: "view_column" }, root.columns[root.columns.length - 1]];
        root.save();
    }

    function renameColumn(id, name) {
        root.columns = root.columns.map(c => c.id === id ? Object.assign({}, c, { name: name }) : c);
        root.save();
    }

    function removeColumn(id) {
        if (root.columns.length <= 2) return;
        const fallback = root.columns.find(c => c.id !== id).id;
        root.tasks = root.tasks.map(t => t.column === id ? Object.assign({}, t, { column: fallback }) : t);
        root.columns = root.columns.filter(c => c.id !== id);
        root.save();
    }

    // Pull in items from the classic sidebar to-do list
    function importTodo() {
        for (const item of Todo.list) {
            if (!root.tasks.some(t => t.title === item.content))
                root.addTask(item.done ? root.doneColumn : root.columns[0].id, item.content);
        }
    }

    FileView {
        id: fileView
        path: root.filePath
        onLoaded: {
            try {
                const data = JSON.parse(fileView.text());
                root.columns = (data.columns && data.columns.length >= 2) ? data.columns : root.defaultColumns;
                root.tasks = data.tasks ?? [];
                root.nextId = data.nextId ?? (Math.max(0, ...root.tasks.map(t => t.id)) + 1);
                root.notifiedIds = data.notifiedIds ?? [];
            } catch (e) {
                console.warn("[Kanban] Failed to parse board:", e);
                root.columns = root.defaultColumns;
            }
            root.loaded = true;
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                root.columns = root.defaultColumns;
                root.loaded = true;
                root.save();
            }
        }
    }

    // Deadline reminders
    Timer {
        running: root.loaded
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            for (const t of root.tasks) {
                if (!t.due || t.column === root.doneColumn || root.notifiedIds.includes(t.id)) continue;
                const d = root.dueDate(t).getTime();
                // Timed tasks: 10 min before. Date-only: from 9:00 that day.
                const remindAt = t.due.length > 10 ? d - 10 * 60000 : d + 9 * 3600000;
                if (now >= remindAt) {
                    Quickshell.execDetached(["notify-send", "-a", "Tasks", "-i", "task-due", Translation.tr("Task due: %1").arg(t.title), root.formatDue(t)]);
                    root.notifiedIds = [...root.notifiedIds, t.id];
                    root.save();
                }
            }
        }
    }

    IpcHandler {
        target: "kanban"
        function add(text: string): void { root.quickAdd(text); }
        function list(): string { return root.tasks.filter(t => t.column !== root.doneColumn).map(t => `${t.id}\t${t.title}`).join("\n"); }
        function done(id: int): void { root.moveTask(id, root.doneColumn); }
    }
}
