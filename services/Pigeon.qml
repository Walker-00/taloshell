pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Client for the pigeon mail daemon (`pigeon daemon`).
 *
 * The daemon speaks newline-delimited JSON over a unix socket in
 * $XDG_RUNTIME_DIR, which is mode 0700, so the passphrase this service sends
 * never leaves the user's own session. Mail itself stays in pigeon's encrypted
 * store; nothing is cached to disk on this side.
 */
Singleton {
    id: root

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") ?? `/tmp/pigeon-${Quickshell.env("UID") ?? ""}`
    readonly property string socketPath: Config.options.mail?.socketPath?.length > 0 ? Config.options.mail.socketPath : `${runtimeDir}/pigeon/daemon.sock`
    // Config arrives asynchronously, and acting before it does would connect to
    // the default socket and spawn a daemon the user may have turned off.
    readonly property bool enabled: Config.ready && (Config.options.mail?.enable ?? false)

    property bool connected: false
    property bool locked: true
    property bool configured: false
    property string version: ""
    property bool vaultExists: false

    property var accounts: []
    property var folders: []
    property var messages: []
    property var outbox: []
    property int unread: 0
    property var unreadByAccount: ({})

    property string currentAccount: ""
    property string currentFolder: ""
    property int messageTotal: 0
    property bool loading: false

    property string lastError: ""
    property string lastNotice: ""
    property var statuses: ({})

    signal newMail(string account, string folder, var messages)
    signal folderListChanged
    signal messageListChanged
    signal unlockFailed(string error)
    signal unlockSucceeded
    signal sent(string id)
    signal sendFailed(string id, string message)

    property int nextId: 1
    property var pending: ({})

    readonly property string syncStatus: {
        const values = Object.values(root.statuses);
        if (values.length === 0) return root.connected ? "idle" : "offline";
        for (const wanted of ["syncing", "connecting", "watching", "idle"]) {
            if (values.includes(wanted)) return wanted;
        }
        return values[0];
    }

    // ---- request plumbing ----

    function request(method, params, callback) {
        if (!root.sock) {
            if (callback) callback({ ok: false, error: "the pigeon daemon is not running" });
            return -1;
        }
        const id = root.nextId++;
        if (callback) root.pending[id] = callback;
        root.sock.write(JSON.stringify({ id: id, method: method, params: params ?? {} }) + "\n");
        root.sock.flush();
        return id;
    }

    function handleLine(line) {
        if (line.trim().length === 0) return;

        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            console.warn("[Pigeon] unparseable line from the daemon:", line.slice(0, 200));
            return;
        }

        if (message.event !== undefined) {
            root.handlePush(message);
            return;
        }

        const callback = root.pending[message.id];
        if (callback) {
            delete root.pending[message.id];
            callback(message);
        } else if (message.ok === false) {
            root.lastError = message.error ?? "";
        }
    }

    function handlePush(push) {
        switch (push.event) {
        case "unlocked":
            root.locked = false;
            root.accounts = push.accounts ?? [];
            if (root.currentAccount === "" && root.accounts.length > 0)
                root.currentAccount = root.accounts[0].name;
            root.unlockSucceeded();
            root.refreshFolders();
            break;
        case "locked":
            root.locked = true;
            root.folders = [];
            root.messages = [];
            root.unread = 0;
            break;
        case "status": {
            const next = Object.assign({}, root.statuses);
            next[push.account] = push.status;
            root.statuses = next;
            break;
        }
        case "folders":
            root.mergeFolders(push.account, push.folders ?? []);
            break;
        case "new-mail":
            root.notifyNewMail(push);
            root.newMail(push.account, push.folder, push.messages ?? []);
            if (push.account === root.currentAccount && push.folder === root.currentFolder)
                root.loadMessages();
            break;
        case "messages":
            if (push.account === root.currentAccount && push.folder === root.currentFolder)
                root.loadMessages();
            break;
        case "removed":
            if (push.account === root.currentAccount && push.folder === root.currentFolder) {
                const gone = push.uids ?? [];
                root.messages = root.messages.filter(m => !gone.includes(m.uid));
                root.messageListChanged();
            }
            break;
        case "flags":
            root.applyFlags(push);
            break;
        case "unread":
            root.unread = push.total ?? 0;
            root.unreadByAccount = push.by_account ?? {};
            break;
        case "outbox":
            root.outbox = push.items ?? [];
            break;
        case "sent":
            root.lastNotice = Translation.tr("Message sent");
            root.sent(push.id ?? "");
            break;
        case "send-failed":
            root.lastError = push.message ?? "";
            root.sendFailed(push.id ?? "", push.message ?? "");
            break;
        case "notice":
            root.lastNotice = push.message ?? "";
            break;
        case "error":
            root.lastError = push.message ?? "";
            break;
        case "shutdown":
            root.connected = false;
            root.locked = true;
            break;
        }
    }

    /// A push carries only one account's folders, so the rest of the list has to
    /// survive the update or a second account would vanish from the sidebar.
    function mergeFolders(account, incoming) {
        const others = root.folders.filter(f => f.account !== account);
        root.folders = others.concat(incoming);
        root.folderListChanged();

        if (root.currentFolder === "" && account === root.currentAccount) {
            const inbox = incoming.find(f => f.role === "inbox") ?? incoming[0];
            if (inbox) root.openFolder(account, inbox.name);
        }
    }

    function applyFlags(push) {
        let touched = false;
        root.messages = root.messages.map(m => {
            if (m.account !== push.account || m.folder !== push.folder || m.uid !== push.uid)
                return m;
            touched = true;
            return Object.assign({}, m, {
                seen: push.seen,
                flagged: push.flagged,
                answered: push.answered,
                draft: push.draft,
                flags: push.flags
            });
        });
        if (touched) root.messageListChanged();
    }

    function notifyNewMail(push) {
        if (!(Config.options.mail?.notifications ?? true)) return;
        const list = push.messages ?? [];
        if (list.length === 0) return;

        const summary = list.length === 1
            ? Translation.tr("Mail from %1").arg(list[0].sender)
            : Translation.tr("%1 new messages").arg(list.length);
        const body = list.slice(0, 4).map(m => `${m.sender}: ${m.subject}`).join("\n");

        Quickshell.execDetached(["notify-send", summary, body, "-a", "pigeon", "-i", "mail-unread"]);
    }

    // ---- state ----

    function refresh() {
        root.request("hello", {}, response => {
            if (!response.ok) return;
            root.locked = response.result.locked;
            root.configured = response.result.configured;
            root.version = response.result.version;
            if (!root.locked) {
                root.refreshAccounts();
                root.refreshFolders();
                root.refreshOutbox();
            }
        });
        root.request("vault-status", {}, response => {
            if (response.ok) root.vaultExists = response.result.exists;
        });
    }

    function refreshAccounts() {
        root.request("accounts", {}, response => {
            if (!response.ok) return;
            root.accounts = response.result ?? [];
            if (root.currentAccount === "" && root.accounts.length > 0)
                root.currentAccount = root.accounts[0].name;
        });
    }

    function refreshFolders() {
        root.request("folders", {}, response => {
            if (!response.ok) return;
            root.folders = response.result ?? [];
            root.folderListChanged();

            if (root.currentFolder === "") {
                const account = root.currentAccount;
                const mine = root.folders.filter(f => account === "" || f.account === account);
                const inbox = mine.find(f => f.role === "inbox") ?? mine[0];
                if (inbox) root.openFolder(inbox.account, inbox.name);
            } else {
                root.loadMessages();
            }
        });
        root.request("status", {}, response => {
            if (!response.ok) return;
            root.unread = response.result.unread ?? 0;
            root.unreadByAccount = response.result.unreadByAccount ?? {};
        });
    }

    function refreshOutbox() {
        root.request("outbox", {}, response => {
            if (response.ok) root.outbox = response.result ?? [];
        });
    }

    function openFolder(account, folder) {
        root.currentAccount = account;
        root.currentFolder = folder;
        root.messages = [];
        root.loadMessages();
    }

    function loadMessages(limit) {
        if (root.currentFolder === "") return;
        root.loading = true;
        root.request("messages", {
            account: root.currentAccount,
            folder: root.currentFolder,
            limit: limit ?? (Config.options.mail?.listLimit ?? 60)
        }, response => {
            root.loading = false;
            if (!response.ok) {
                root.lastError = response.error ?? "";
                return;
            }
            // A slow reply for a folder the user has already left must not
            // overwrite what they are looking at now.
            if (response.result.folder !== root.currentFolder) return;
            root.messages = response.result.messages ?? [];
            root.messageTotal = response.result.total ?? 0;
            root.messageListChanged();
        });
    }

    function loadMessage(message, wantHtml, callback) {
        root.request("message", {
            account: message.account,
            folder: message.folder,
            uid: message.uid,
            html: wantHtml === true,
            width: Config.options.mail?.wrapWidth ?? 92
        }, callback);
    }

    // ---- actions ----

    function unlock(passphrase) {
        root.request("unlock", { passphrase: passphrase }, response => {
            if (response.ok) {
                root.locked = false;
                root.accounts = response.result.accounts ?? [];
                root.unlockSucceeded();
                root.refreshFolders();
            } else {
                root.lastError = response.error ?? "";
                root.unlockFailed(response.error ?? "");
            }
        });
    }

    function lock() {
        root.request("lock", {}, () => root.refresh());
    }

    function createVault(passphrase, callback) {
        root.request("vault-create", { passphrase: passphrase }, response => {
            if (response.ok) root.vaultExists = true;
            if (callback) callback(response);
        });
    }

    function keyOf(message) {
        return { account: message.account, folder: message.folder, uid: message.uid };
    }

    function mark(messages, changes) {
        const list = Array.isArray(messages) ? messages : [messages];
        root.request("mark", Object.assign({ keys: list.map(root.keyOf) }, changes));
    }

    function setSeen(message, seen) {
        root.mark(message, { seen: seen });
    }

    function toggleFlag(message) {
        root.mark(message, { flagged: !message.flagged });
    }

    function moveTo(messages, folder) {
        const list = Array.isArray(messages) ? messages : [messages];
        root.request("move", { keys: list.map(root.keyOf), to: folder });
    }

    /// Falls back to a delete when the account has no archive folder mapped,
    /// rather than silently doing nothing.
    function archive(message) {
        const target = root.folders.find(f => f.account === message.account && f.role === "archive");
        if (target) root.moveTo(message, target.name);
        else root.trash(message);
    }

    function trash(message) {
        root.request("delete", { keys: [root.keyOf(message)], permanent: false });
    }

    function sync(account) {
        root.request("sync", account ? { account: account } : {});
    }

    function send(draft, callback) {
        root.request("send", draft, callback);
    }

    function saveDraft(draft, callback) {
        root.request("draft", draft, callback);
    }

    function flushOutbox() {
        root.request("flush", {});
    }

    function search(text, callback) {
        root.request("search", { query: text, limit: Config.options.mail?.searchLimit ?? 80 }, callback);
    }

    function saveAttachment(message, part, callback) {
        root.request("attachment", {
            account: message.account,
            folder: message.folder,
            uid: message.uid,
            part: part
        }, callback);
    }

    function openAttachment(message, part) {
        root.saveAttachment(message, part, response => {
            if (response.ok) Quickshell.execDetached(["xdg-open", response.result.path]);
            else root.lastError = response.error ?? "";
        });
    }

    // ---- setup and settings, so no terminal is needed ----

    function autoconfig(email, callback) {
        root.request("autoconfig", { email: email }, callback);
    }

    function testAccount(spec, callback) {
        root.request("test-account", spec, callback);
    }

    function addAccount(spec, callback) {
        root.request("account-add", spec, response => {
            if (response.ok) {
                root.accounts = response.result.accounts ?? [];
                root.refreshFolders();
            }
            if (callback) callback(response);
        });
    }

    function removeAccount(name, callback) {
        root.request("account-remove", { name: name }, response => {
            if (response.ok) {
                root.accounts = response.result.accounts ?? [];
                root.folders = root.folders.filter(f => f.account !== name);
                if (root.currentAccount === name) {
                    root.currentAccount = root.accounts.length > 0 ? root.accounts[0].name : "";
                    root.currentFolder = "";
                    root.messages = [];
                }
                root.refreshFolders();
            }
            if (callback) callback(response);
        });
    }

    function updateAccount(name, changes, callback) {
        root.request("account-update", Object.assign({ name: name }, changes), response => {
            if (response.ok) root.accounts = response.result.accounts ?? [];
            if (callback) callback(response);
        });
    }

    function setPassword(account, kind, password, callback) {
        root.request("set-password", { account: account, kind: kind, password: password }, callback);
    }

    function daemonSettings(callback) {
        root.request("settings-get", {}, callback);
    }

    function setDaemonSettings(changes, callback) {
        root.request("settings-set", changes, callback);
    }

    // ---- transport ----

    // Set once the daemon binary turns out not to be startable, so a missing
    // pigeon does not mean a spawn attempt every few seconds forever.
    property bool daemonUnavailable: false

    readonly property var sock: socketLoader.item

    /// `Socket.connected` reports the state that was *asked* of it rather than
    /// whether a server answered, so a failed attempt cannot be retried by
    /// setting it again. Building a fresh Socket is what actually reconnects.
    function tryConnect() {
        if (!root.enabled || root.connected) return;
        // Callbacks waiting on the socket being replaced will never be answered.
        root.pending = ({});
        socketLoader.active = false;
        socketLoader.active = true;
    }

    // One spawn per disconnected stretch. Without this, every failed connect
    // while a daemon is already listening starts another that immediately exits
    // because the socket is taken.
    property bool daemonSpawnTried: false

    function startDaemonIfWanted() {
        if (root.daemonUnavailable || root.daemonSpawnTried) return;
        if (!root.enabled || !(Config.options.mail?.autostartDaemon ?? true)) return;
        root.daemonSpawnTried = true;
        daemonProcess.running = true;
    }

    onEnabledChanged: {
        if (!root.enabled) {
            socketLoader.active = false;
            root.connected = false;
            return;
        }
        root.startDaemonIfWanted();
        root.tryConnect();
    }

    Loader {
        id: socketLoader
        active: false

        sourceComponent: Component {
            Socket {
                id: socket
                path: root.socketPath
                connected: true

                parser: SplitParser {
                    splitMarker: "\n"
                    onRead: data => root.handleLine(data)
                }

                onConnectionStateChanged: {
                    if (socket.connected) return;
                    root.connected = false;
                    // Every in-flight callback belongs to a socket that is gone,
                    // so dropping them stops a reply being matched to a later
                    // request that happens to reuse the id.
                    root.pending = ({});
                    root.locked = true;
                }

                onError: error => root.startDaemonIfWanted()

                Component.onCompleted: greetTimer.restart()
            }
        }
    }

    // A connect that fails still leaves `connected` true, so the only proof the
    // daemon is really there is a reply. `hello` is that proof.
    Timer {
        id: greetTimer
        interval: 50
        onTriggered: {
            root.request("hello", {}, response => {
                if (!response.ok) return;
                root.connected = true;
                root.daemonSpawnTried = false;
                root.lastError = "";
                root.locked = response.result.locked;
                root.configured = response.result.configured;
                root.version = response.result.version;
                root.request("subscribe", { events: true });
                root.refresh();
            });
        }
    }

    Process {
        id: daemonProcess
        command: [Config.options.mail?.command?.length > 0 ? Config.options.mail.command : "pigeon", "daemon"]

        property bool everStarted: false

        onStarted: {
            daemonProcess.everStarted = true;
            root.daemonUnavailable = false;
        }

        // A binary that cannot be launched at all never emits `exited`, so the
        // only signal of a missing pigeon is running going false without a start.
        onRunningChanged: {
            if (daemonProcess.running) return;
            if (!daemonProcess.everStarted) {
                root.daemonUnavailable = true;
                root.lastError = Translation.tr("Could not start `%1 daemon`. Is pigeon installed?")
                    .arg(daemonProcess.command[0]);
            }
            daemonProcess.everStarted = false;
        }

        onExited: code => {
            if (code !== 0)
                console.warn(`[Pigeon] the daemon exited with ${code}`);
        }
    }

    // A changed command or socket is the user saying "try again".
    Connections {
        target: Config.options.mail ?? null

        function onCommandChanged() {
            root.daemonUnavailable = false;
            root.daemonSpawnTried = false;
            root.startDaemonIfWanted();
        }

        function onSocketPathChanged() {
            root.daemonUnavailable = false;
            root.tryConnect();
        }
    }

    Timer {
        // The daemon may start after the shell, or be restarted under it. A
        // binding cannot express this: `connected` only retries when it is
        // assigned again.
        running: root.enabled && !root.connected
        interval: 1500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tryConnect()
    }

    Component.onCompleted: {
        root.startDaemonIfWanted();
        root.tryConnect();
    }
}
