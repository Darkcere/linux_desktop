// 💡 THE FIX: Hoisted static array so it is allocated exactly once on boot, not per-notification
const CHROMIUM_BROWSERS = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];

const getFriendlyNotifTimeString = (timestamp) => {
    if (!timestamp) return '';
    const messageTime = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - messageTime.getTime();

    // Less than 1 minute
    if (diffMs < 60000) return 'Now';

    // Same day - show relative time
    if (messageTime.toDateString() === now.toDateString()) {
        const diffMinutes = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);

        if (diffHours > 0) {
            return `${diffHours}h`;
        } else {
            return `${diffMinutes}m`;
        }
    }

    // Multiple days - show relative days
    // 💡 THE FIX: Removed the dead "Yesterday" code block below this, as diffDays > 0 always catches it first!
    const diffDays = Math.floor(diffMs / 86400000);
    if (diffDays > 0) {
        return `${diffDays}d`;
    }

    // Older dates (fallback for very old notifications)
    return Qt.formatDateTime(messageTime, "MMMM dd");
};

const processNotificationBody = (body, appName) => {
    if (!body) return "";

    // Limpiar notificaciones de navegadores basados en Chromium
    if (appName) {
        const lowerApp = appName.toLowerCase();

        // 💡 THE FIX: Lightning fast traditional loop over the hoisted array
        let isChromium = false;
        for (let i = 0; i < CHROMIUM_BROWSERS.length; i++) {
            if (lowerApp.includes(CHROMIUM_BROWSERS[i])) {
                isChromium = true;
                break;
            }
        }

        if (isChromium && body.startsWith('<a')) {
            // 💡 THE FIX: Indexing a substring is vastly faster than split/slice/join operations
            const splitIndex = body.indexOf('\n\n');
            if (splitIndex !== -1) {
                return body.substring(splitIndex + 2);
            }
        }
    }

    // No reemplazar saltos de línea con espacios
    return body;
};