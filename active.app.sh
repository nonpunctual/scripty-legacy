#!/bin/bash
#
# Watches for macOS foreground-app switches and prints one JSON line per
# switch as they happen.
#
# The watcher is JavaScript for Automation (JXA); the bash wrapper hands
# it to osascript on stdin: ./active.app.sh
#
# Usage:
#   ./active.app.sh        # runs until interrupted (Ctrl-C)
#   ./active.app.sh 60     # exits automatically after 60 seconds

DURATION="${1:-}"
if [ -n "$DURATION" ] && ! [[ "$DURATION" =~ ^[0-9]+$ ]]
then
    echo "error: duration must be a positive integer number of seconds" >&2; exit 1
fi

export DURATION="${DURATION:-0}"

/usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import('Cocoa');

const startTime = Date.now();
const durationEnv = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey('DURATION'));
const duration = parseInt(durationEnv, 10) || 0;

function record(app) {
    const elapsed = Math.floor((Date.now() - startTime) / 1000);
    const out = {
        active_app: {
            app_name: ObjC.unwrap(app.localizedName),
            bundle_id: ObjC.unwrap(app.bundleIdentifier),
            pid: String(app.processIdentifier),
            time_elapsed: String(elapsed)
        }
    };
    console.log(JSON.stringify(out));
}

ObjC.registerSubclass({
    name: 'ActiveAppObserver',
    methods: {
        'appActivated:': {
            types: ['void', ['id']],
            implementation: function (notification) {
                const app = notification.userInfo.objectForKey('NSWorkspaceApplicationKey');
                record(app);
            }
        }
    }
});

const observer = $.ActiveAppObserver.alloc.init;
const nc = $.NSWorkspace.sharedWorkspace.notificationCenter;
nc.addObserverSelectorNameObject(
    observer,
    'appActivated:',
    'NSWorkspaceDidActivateApplicationNotification',
    $()
);

// Emit foreground app
record($.NSWorkspace.sharedWorkspace.frontmostApplication);

if (duration > 0) {
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(duration));
} else {
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.distantFuture);
}
JXA

if [ "$DURATION" != "0" ]
then
    printf "\nWatched for %ss... Exiting.\n\n" "$DURATION" >&2
fi
