#!/usr/bin/env bash
# whereami: answer "what environment is this agent running in?" as key=value lines.
# every key always prints; "unknown" is the default, never a missing line.
# reads only: no network, no writes, never prints secrets.

kv() { printf '%s=%s\n' "$1" "${2:-unknown}"; }
has() { command -v "$1" >/dev/null 2>&1; }

# --- machine -----------------------------------------------------------
os_id=unknown
[ -r /etc/os-release ] && os_id=$(. /etc/os-release; echo "${ID:-unknown}")
kv machine.host "$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null)"
kv machine.os "$(uname -s 2>/dev/null)"
kv machine.distro "$os_id"
kv machine.kernel "$(uname -r 2>/dev/null)"
kv machine.arch "$(uname -m 2>/dev/null)"
kv machine.user "$(id -un 2>/dev/null)"

# --- isolation: container / vm / wsl ------------------------------------
container=none
if has systemd-detect-virt; then
  c=$(systemd-detect-virt --container 2>/dev/null); [ -n "$c" ] && container=$c
fi
if [ "$container" = none ]; then
  if [ -f /.dockerenv ]; then container=docker
  elif [ -f /run/.containerenv ]; then container=podman
  elif grep -qaE 'docker|kubepods|containerd|lxc' /proc/1/cgroup 2>/dev/null; then container=cgroup-hint
  fi
fi
vm=none
if has systemd-detect-virt; then
  v=$(systemd-detect-virt --vm 2>/dev/null); [ -n "$v" ] && vm=$v
fi
wsl=no
{ [ -n "$WSL_DISTRO_NAME" ] || grep -qi microsoft /proc/version 2>/dev/null; } && wsl=${WSL_DISTRO_NAME:-yes}
kv isolation.container "$container"
kv isolation.vm "$vm"
kv isolation.wsl "$wsl"
kv isolation.pid1 "$(cat /proc/1/comm 2>/dev/null)"

# --- access: how a human reaches this shell -----------------------------
ssh=no; [ -n "$SSH_CONNECTION" ] && ssh=yes
kv access.ssh "$ssh"
kv access.multiplexer "$( [ -n "$TMUX" ] && echo tmux || { [ -n "$ZELLIJ" ] && echo zellij; } || { [ -n "$STY" ] && echo screen; } || echo none)"
kv access.terminal "${TERM_PROGRAM:-${TERM:-none}}"

# --- agent harness -------------------------------------------------------
agent=none; [ "$CLAUDECODE" = 1 ] && agent=claude-code
kv agent.harness "$agent"
kv agent.entrypoint "${CLAUDE_CODE_ENTRYPOINT}"           # observed: claude-desktop, cli
kv agent.remote "${CLAUDE_CODE_REMOTE:-false}"            # set in cloud (web) sessions
kv agent.version "$(basename "$(dirname "$(dirname "${CLAUDE_CODE_EXECPATH:-/x/unknown/x/x}")")")"
kv agent.sdk_version "${CLAUDE_AGENT_SDK_VERSION}"
kv agent.desktop_version "${CLAUDE_CODE_DESKTOP_APP_VERSION:-none}"
kv agent.session_id "${CLAUDE_CODE_SESSION_ID}"
kv agent.host_session_id "${CLAUDE_CODE_HOST_SESSION_ID:-none}"
kv agent.child_session "${CLAUDE_CODE_CHILD_SESSION:-0}"
kv agent.attended "${CLAUDE_CODE_SESSION_ATTENDED:-unknown}"
kv agent.effort "${CLAUDE_EFFORT}"
kv agent.messaging_socket "$( [ -S "$CLAUDE_CODE_MESSAGING_SOCKET" ] && echo present || echo none)"

# --- workspace -----------------------------------------------------------
kv workspace.cwd "$PWD"
case "$PWD" in
  */scratch-workspaces/*) ws=scratch ;;
  */worktrees/*|*/.worktrees/*) ws=worktree ;;
  *) ws=folder ;;
esac
kv workspace.kind "$ws"
if has git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  kv workspace.git yes
  kv workspace.git_root "$(git rev-parse --show-toplevel)"
  kv workspace.git_branch "$(git branch --show-current 2>/dev/null)"
  kv workspace.git_linked_worktree "$( [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ] && echo yes || echo no)"
else
  kv workspace.git no
  kv workspace.git_root none
  kv workspace.git_branch none
  kv workspace.git_linked_worktree no
fi
