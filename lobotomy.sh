#!/bin/sh

# Wipes Claude Code local state: top-level caches/logs/scratch dirs, then
# per-project session data under ~/.claude/projects (each project's "memory"
# dir is always kept). Projects listed in exclude_projects are skipped, i.e.,
# the session data in the excluded project dirs is kept, not deleted.


# populate Claude Code project dir exclusions
exclude_projects=(
    -Users-Shared-rotten
    -Users-Shared-fleet-mcp-plus
    -Users-Shared-network-health-extension
)


##### DO NOT MODIFY BELOW #####


# wait for Claude Code to write state
/bin/sleep 5


# delete top-level Claude Code state and scratch dirs
/bin/rm -f -r \
    ~/.claude/history.jsonl \
    ~/.claude/.last-cleanup \
    ~/.claude/plugins/.last_inuse_sweep \
    /private/tmp/cc-socks/ \
    /private/tmp/claude-501/

/usr/bin/find ~/.claude/backups -mindepth 1 -maxdepth 1 -name ".[^.]*" -exec rm -f -r {} + 2>/dev/null

for i in agents debug downloads file-history image-cache jobs paste-cache plans session-env sessions shell-snapshots telemetry
do
    /usr/bin/find ~/.claude/"$i" -mindepth 1 -exec rm -f -r {} + 2>/dev/null
done


# delete per-project state skipping excluded projects
for project in ~/.claude/projects/*/
do
    for excluded in "${exclude_projects[@]}"
    do
        case "$project" in
            */"$excluded"/ ) continue 2 ;;
        esac
    done
    /usr/bin/find "$project" -mindepth 1 -maxdepth 1 ! -name "memory" -exec rm -f -r {} +
done
