#!/usr/bin/env bash
set -Eeuo pipefail
export OHAMLAB_DEBUG="${OHAMLAB_DEBUG:-0}"
export OHAMLAB_REFRESH_PLUGINS="${OHAMLAB_REFRESH_PLUGINS:-0}"
export OHAMLAB_REFRESH_AUDIO="${OHAMLAB_REFRESH_AUDIO:-0}"
START_SECONDS=$SECONDS
log_stage() { echo "[TIMING] +$((SECONDS - START_SECONDS))s $*"; }
# ============================================================
# OHAMLAB HARNESS CONFIGURATION
# ============================================================
export OHAMLAB_HARNESS_HOME="${OHAMLAB_HARNESS_HOME:-/app/ohamlab-harness}"
export DSH_HOME=/data/dsh
export OHAMLAB_PERSISTENT_DSH_HOME=/data/dsh
export DSH_HOST="${DSH_HOST:-127.0.0.1}"
export DSH_PORT="${DSH_PORT:-3080}"
export PORT="${PORT:-7860}"
INSTALL_MARKER="${DSH_HOME}/.ohamlab-installed-v2"
export HARNS_BRAND_NAME="OhamLab"
# VoiceStudio Python service
export OHAMLAB_AUDIO_REPO="${OHAMLAB_AUDIO_REPO:-https://github.com/innokria/ohamlab-voicestudio.git}"
export OHAMLAB_AUDIO_HOME="${OHAMLAB_AUDIO_HOME:-/app/ohamlab-voicestudio}"
export OHAMLAB_AUDIO_VENV="${OHAMLAB_AUDIO_VENV:-/app/ohamlab-voice-venv}"
export OHAMLAB_AUDIO_HOST="${OHAMLAB_AUDIO_HOST:-127.0.0.1}"
export OHAMLAB_AUDIO_PORT="${OHAMLAB_AUDIO_PORT:-8765}"
export OHAMLAB_AUDIO_MODEL="${OHAMLAB_AUDIO_MODEL:-rahul7star/tts-nano-o-hi}"
AUDIO_PID=""
BACKUP_PID=""
HARNESS_PID=""
# ============================================================
# DISABLE DSH SESSION TELEMETRY
# ============================================================
export DSH_TELEMETRY_MODE="DISABLED"
export DSH_TELEMETRY_OTLP_URL=""
export OTEL_SDK_DISABLED="true"
echo "[OHAMLAB] Session telemetry disabled."
# ============================================================
# SESSION PERSISTENCE CONFIGURATION
# ============================================================
SESSION_DIR="${DSH_HOME}/sessions"
LOCAL_SESSION_DIR="${OHAMLAB_LOCAL_SESSION_DIR:-/tmp/ohamlab-dsh-sessions}"
BACKUP_DIR="${OHAMLAB_PERSISTENT_DSH_HOME}/session-backup"
BACKUP_FILE="${BACKUP_DIR}/sessions.tar.gz"
BACKUP_INTERVAL=3600
echo "=========================================================="
echo "[OHAMLAB] Starting OhamLab Harness"
echo "=========================================================="
# ============================================================
# PREPARE DIRECTORIES
# ============================================================
mkdir -p \
    "${DSH_HOME}/plugins" \
    "${DSH_HOME}/skills" \
    "${DSH_HOME}/profiles" \
    "${BACKUP_DIR}" \
    "${DSH_HOME}/cache" \
    "${DSH_HOME}/logs" \
    "${LOCAL_SESSION_DIR}"
# ============================================================
# USE PERSISTENT PROFILE DIRECTLY
# ============================================================
echo "[OHAMLAB] DSH_HOME: ${DSH_HOME}"
echo "[OHAMLAB] Standard CLI profile: ${DSH_HOME}/profiles/web"
if [ -f "${DSH_HOME}/web/profile/package.json" ]; then
    echo '[OHAMLAB] NOTE: /data/dsh/web/profile exists; CLI uses profiles/web.'
fi
# Active sessions must remain on a local POSIX filesystem.
if [ -L "${SESSION_DIR}" ]; then
    if [ "$(readlink -f "${SESSION_DIR}")" != "$(readlink -f "${LOCAL_SESSION_DIR}")" ]; then
        echo "[OHAMLAB] ERROR: Existing sessions symlink points elsewhere."
        exit 1
    fi
elif [ -e "${SESSION_DIR}" ]; then
    echo "[OHAMLAB] ERROR: ${SESSION_DIR} is an existing directory on HF storage."
    echo '[OHAMLAB] Existing data was NOT changed.'
    exit 1
else
    ln -s "${LOCAL_SESSION_DIR}" "${SESSION_DIR}"
fi
printf test > "${LOCAL_SESSION_DIR}/.hardlink-test.tmp"
ln "${LOCAL_SESSION_DIR}/.hardlink-test.tmp" "${LOCAL_SESSION_DIR}/.hardlink-test"
rm -f "${LOCAL_SESSION_DIR}/.hardlink-test.tmp" "${LOCAL_SESSION_DIR}/.hardlink-test"
echo '[OHAMLAB] PASS: local session hard-link test'
# ============================================================
# VERIFY DEPENDENCIES
# ============================================================
echo "[OHAMLAB] Checking dependencies..."
if command -v python3 >/dev/null 2>&1; then
    python3 --version
elif command -v python >/dev/null 2>&1; then
    python --version
else
    echo '[OHAMLAB] ERROR: Python is required by this deployment.'
    exit 1
fi
if command -v ohamlab-harness >/dev/null 2>&1; then
    ohamlab-harness --version || echo '[OHAMLAB] WARNING: harness version check failed'
else
    echo '[OHAMLAB] ERROR: ohamlab-harness command not found.'
    exit 1
fi
command -v tar >/dev/null || {
    echo "[OHAMLAB] ERROR: tar is not installed."
    exit 1
}
# ============================================================
# SESSION BACKUP
# ============================================================
backup_sessions() {
    local TEMP_BACKUP="/tmp/ohamlab-session-backup.$$.tar.gz"
    echo "[OHAMLAB] Creating session backup..."
    if tar -czf "${TEMP_BACKUP}" \
        -C "$(dirname "${LOCAL_SESSION_DIR}")" \
        "$(basename "${LOCAL_SESSION_DIR}")"; then
        mv -f "${TEMP_BACKUP}" "${BACKUP_FILE}"
        echo "[OHAMLAB] Session backup successful."
        echo "[OHAMLAB] Backup: ${BACKUP_FILE}"
    else
        rm -f "${TEMP_BACKUP}"
        echo "[OHAMLAB] ERROR: Session backup failed."
        return 1
    fi
}
# ============================================================
# RESTORE SESSIONS
# ============================================================
restore_sessions() {
    if [ ! -f "${BACKUP_FILE}" ]; then
        echo "[OHAMLAB] No previous session backup found."
        return 0
    fi
    if [ -z "$(find "${LOCAL_SESSION_DIR}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        echo "[OHAMLAB] Restoring previous sessions..."
        if tar -tzf "${BACKUP_FILE}" >/dev/null 2>&1; then
            tar -xzf "${BACKUP_FILE}" \
                -C "${LOCAL_SESSION_DIR}" \
                --strip-components=1
            echo "[OHAMLAB] Session restoration successful."
        else
            echo "[OHAMLAB] ERROR: Invalid session backup."
            return 1
        fi
    else
        echo "[OHAMLAB] Existing local sessions detected."
        echo "[OHAMLAB] Skipping restoration."
    fi
}
# ============================================================
# HOURLY BACKUP WORKER
# ============================================================
hourly_backup() {
    echo "[OHAMLAB] Hourly session backup enabled."
    while true; do
        sleep "${BACKUP_INTERVAL}"
        backup_sessions || true
    done
}
# ============================================================
# INSTALL OR REPAIR OHAMLAB HARNESS
# ============================================================
if [ ! -f "${INSTALL_MARKER}" ] || \
   [ ! -f "${OHAMLAB_HARNESS_HOME}/app/package.json" ]; then
    echo "[OHAMLAB] Installation missing or incomplete."
    echo "[OHAMLAB] Running installation..."
    ohamlab-harness install --force
    if [ ! -f "${OHAMLAB_HARNESS_HOME}/app/package.json" ]; then
        echo "[OHAMLAB] ERROR: Harness installation failed."
        exit 1
    fi
    touch "${INSTALL_MARKER}"
    echo "[OHAMLAB] Installation verified."
else
    echo "[OHAMLAB] Existing OhamLab installation detected."
fi
restore_sessions
# ============================================================
# OPTIONAL PLUGINS
# ============================================================
echo
echo "=========================================================="
echo "[OHAMLAB] Installing optional plugins"
echo "=========================================================="
export PROBE_DISABLED=1
# Locate the actual Harness checkout.
resolve_dsh_app_dir() {
    local root
    for root in \
        "${OHAMLAB_HARNESS_HOME}/app" \
        "${OHAMLAB_HARNESS_HOME}" \
        /app/deepseek-harness \
        /app/deepseek-harness/app; do
        if [ -f "${root}/package.json" ] && \
           [ -f "${root}/apps/cli/src/bin.ts" ]; then
            printf '%s\n' "${root}"
            return 0
        fi
    done
    return 1
}
if ! DSH_APP_DIR="$(resolve_dsh_app_dir)"; then
    echo '[OHAMLAB] ERROR: Cannot locate Harness source.'
    exit 1
fi
export DSH_APP_DIR
echo "[OHAMLAB] Harness app directory: ${DSH_APP_DIR}"
cd "${DSH_APP_DIR}"
PROFILE_DIR="${DSH_HOME}/profiles/web"
mkdir -p "${PROFILE_DIR}"
# Check both profile metadata and installed package files.
plugin_declared() {
    node -e 'try { const p=require(process.argv[1]); process.exit(Object.hasOwn(p.dependencies || {},process.argv[2]) ? 0 : 1) } catch { process.exit(1) }' "${PROFILE_DIR}/package.json" "$1"
}
plugin_ready() {
    plugin_declared "$1" && [ -f "${PROFILE_DIR}/node_modules/$1/package.json" ]
}
# Client plugins need not be profile bundles. Keep their dependencies intact.
plugin_bundle_ready() {
    plugin_ready "$1" && node -e 'try { const p=require(process.argv[1]); const m=require(process.argv[3]); const listed=p.dsh?.profile?.bundles?.includes(process.argv[2]) || false; process.exit(listed === Boolean(m.dsh?.bundle) ? 0 : 1) } catch { process.exit(1) }' "${PROFILE_DIR}/package.json" "$1" "${PROFILE_DIR}/node_modules/$1/package.json"
}
repair_ohamlab_bundles() {
    PROFILE_PACKAGE="${PROFILE_DIR}/package.json" node <<'NODE'
const fs = require('fs');
const path = require('path');
const file = process.env.PROFILE_PACKAGE;
if (!fs.existsSync(file)) process.exit(0);
const p = JSON.parse(fs.readFileSync(file, 'utf8'));
const bundles = p.dsh?.profile?.bundles;
if (!Array.isArray(bundles)) process.exit(0);
const managed = new Set(['@ohamlab/harness-brand', '@ohamlab/harness-voice']);
const next = bundles.filter(name => {
  if (!managed.has(name)) return true;
  try {
    const m = JSON.parse(fs.readFileSync(path.join(path.dirname(file), 'node_modules', name, 'package.json'), 'utf8'));
    if (m.dsh?.bundle) return true;
  } catch (e) { console.warn('[BUNDLE] ' + e.message); }
  console.warn('[BUNDLE] Removing invalid profile bundle: ' + name);
  return false;
});
if (next.length !== bundles.length) {
  fs.copyFileSync(file, file + '.before-bundle-repair');
  p.dsh.profile.bundles = next;
  fs.writeFileSync(file, JSON.stringify(p, null, 2) + '\n');
}
NODE
}
# Repair persisted metadata before any DSH plugin commands.
repair_ohamlab_bundles
log_stage "Plugin checks"
# ------------------------------------------------------------
# REMOVE KNOWN INCOMPATIBLE PLUGINS
# ------------------------------------------------------------
echo "[PLUGIN] Removing known incompatible plugins..."
BAD_PLUGINS=(
    "dsh-better-sidebar"
    "@deepseek-ai/dsh-session"
    "dsh-context"
    "dsh-ui-appearance"
    "@linxin666/dsh-client-ui-task-board"
    "@dickpy/dsh-imagegen"
    "dsh-llm-qwen-local"
    "dsh-opencode-free-models"
    "dsh-free-search"
    "dsh-free-model-command"
)
for PLUGIN in "${BAD_PLUGINS[@]}"; do
    if ! plugin_declared "${PLUGIN}" && [ ! -e "${PROFILE_DIR}/node_modules/${PLUGIN}" ]; then
        continue
    fi
    echo "[PLUGIN] Disabling: ${PLUGIN}"
    pnpm dsh plugin --profile web remove "${PLUGIN}" \
        >/tmp/plugin-remove.log 2>&1 || true
    rm -rf \
        "${PROFILE_DIR}/node_modules/${PLUGIN}" \
        "${PROFILE_DIR}/node_modules/.pnpm"/"${PLUGIN}"* \
        2>/dev/null || true
done
# ------------------------------------------------------------
# INSTALL OPTIONAL THIRD-PARTY PLUGINS
# ------------------------------------------------------------
PLUGINS=(
    "@hytime/dsh-client-ui-shortcuts@0.1.12"
    "dshmarket"
    "dsh-skill-picker"
    "@deepseek-ai/dsh-mcp-client"
    "https://github.com/innokria/dsh-ohamlab-agent-lab.git#2.0"
)
for PLUGIN in "${PLUGINS[@]}"; do
    echo
    case "$PLUGIN" in
        https://*) NAME="${PLUGIN##*/}"; NAME="${NAME%%.git*}" ;;
        @hytime/*@*) NAME="${PLUGIN%@*}" ;;
        *) NAME="$PLUGIN" ;;
    esac
    if [ "$OHAMLAB_REFRESH_PLUGINS" = 0 ] && { plugin_ready "$NAME" || { [ "$NAME" = "@hytime/dsh-client-ui-shortcuts" ] && [ -f "${PROFILE_DIR}/.shortcuts-disabled" ]; }; }; then
        echo "[PLUGIN] Already installed: $NAME"
        continue
    fi
    echo "[PLUGIN] Installing: ${PLUGIN}"
    if pnpm dsh plugin --profile web add "${PLUGIN}"; then
        echo "[PLUGIN] OK: ${PLUGIN}"
    else
        echo "[PLUGIN] WARNING: failed to install ${PLUGIN}"
        echo "[PLUGIN] Continuing without ${PLUGIN}"
    fi
done
echo
echo "[PLUGIN] Approving optional build scripts..."
if [ "$OHAMLAB_REFRESH_PLUGINS" = 1 ] || [ ! -f "${PROFILE_DIR}/.ohamlab-builds-approved" ]; then
    if pnpm approve-builds --all >/tmp/plugin-approve.log 2>&1; then
        touch "${PROFILE_DIR}/.ohamlab-builds-approved"
    fi
fi
# ============================================================
# OHAMLAB PLUGIN SOURCE RESOLUTION
# ============================================================
resolve_ohamlab_plugin() {
    local name="$1"
    local root
    for root in \
        /app/ohamlab/plugins \
        "${OHAMLAB_HARNESS_HOME}/vendor/ohamlab/plugins" \
        "${OHAMLAB_HARNESS_HOME}/app/vendor/ohamlab/plugins" \
        "${OHAMLAB_HARNESS_HOME}/plugins" \
        /app/deepseek-harness/ohamlab/vendor/ohamlab/plugins \
        /app/deepseek-harness/vendor/ohamlab/plugins; do
        if [ -f "${root}/${name}/package.json" ]; then
            printf '%s\n' "${root}/${name}"
            return 0
        fi
    done
    return 1
}
# ------------------------------------------------------------
# FETCH PLUGIN FROM HARNESS REPOSITORY
# ------------------------------------------------------------
fetch_ohamlab_plugin() {
    local name="$1"
    local ref="$2"
    local repo="${OHAMLAB_REPO_URL:-https://github.com/innokria/ohamlab-deepseek-harness.git}"
    local dest="/app/ohamlab/plugins/${name}"
    local tmp
    tmp="$(mktemp -d /tmp/ohamlab-plugin.XXXXXX)"
    echo "[OHAMLAB] Fetching ${name} at ${ref}"
    if (
        cd "${tmp}" &&
        git init -q &&
        git remote add origin "${repo}" &&
        git config core.sparseCheckout true &&
        printf 'vendor/ohamlab/plugins/%s/\n' "${name}" > .git/info/sparse-checkout &&
        git fetch -q --depth 1 origin "${ref}" &&
        git checkout -q FETCH_HEAD &&
        test -f "vendor/ohamlab/plugins/${name}/package.json"
    ); then
        mkdir -p /app/ohamlab/plugins
        rm -rf "${dest}"
        cp -a "${tmp}/vendor/ohamlab/plugins/${name}" "${dest}"
        rm -rf "${tmp}"
        return 0
    fi
    rm -rf "${tmp}"
    return 1
}
# ============================================================
# INSTALL BRAND + VOICE PLUGINS
# ============================================================
install_ohamlab_web_plugins() {
    # These are optional UI enhancements. Never prevent the Harness starting.
    local profile="${DSH_HOME}/profiles/web"
    local brand_source="" voice_source="" source="" pkg=""
    local brand_ok=0 voice_ok=0

    mkdir -p "${profile}" || {
        echo '[OHAMLAB] WARNING: cannot create web profile; skipping OhamLab UI plugins'
        return 0
    }
    command -v pnpm >/dev/null 2>&1 || {
        echo '[OHAMLAB] WARNING: pnpm unavailable; skipping OhamLab UI plugins'
        return 0
    }

    # Resolve/fetch sources independently. Voice is used exactly as committed:
    # client.js + index.js + package.json + cordis patch; no build step.
    if brand_source="$(resolve_ohamlab_plugin harness-brand)"; then
        :
    elif fetch_ohamlab_plugin harness-brand "${OHAMLAB_BRAND_REF:-2.0}"; then
        brand_source="/app/ohamlab/plugins/harness-brand"
    else
        echo '[OHAMLAB] WARNING: branding source unavailable; continuing without branding'
    fi

    if voice_source="$(resolve_ohamlab_plugin harness-voice)"; then
        :
    elif fetch_ohamlab_plugin harness-voice "${OHAMLAB_VOICE_REF:-main}"; then
        voice_source="/app/ohamlab/plugins/harness-voice"
    else
        echo '[OHAMLAB] WARNING: voice source unavailable; continuing without microphone icon'
    fi

    # Branding plugin may need its own build output. Voice must NOT be built.
    if [ -n "${brand_source}" ] && [ -f "${brand_source}/package.json" ]; then
        if [ ! -s "${brand_source}/lib/client.js" ]; then
            echo '[OHAMLAB] Building branding plugin...'
            ( cd "${brand_source}" && pnpm install --no-frozen-lockfile && pnpm run build ) \
                || echo '[OHAMLAB] WARNING: branding build failed; continuing'
        fi
        if [ -s "${brand_source}/lib/client.js" ]; then
            ( cd "${DSH_APP_DIR}" && pnpm dsh plugin --profile web add "${brand_source}" ) \
                && brand_ok=1 \
                || echo '[OHAMLAB] WARNING: branding registration failed; continuing'
        else
            echo '[OHAMLAB] WARNING: branding bundle missing; skipping branding plugin'
        fi
    else
        echo '[OHAMLAB] WARNING: valid branding package not found; skipping'
    fi

    if [ -n "${voice_source}" ] && [ -f "${voice_source}/package.json" ]; then
        if [ ! -s "${voice_source}/client.js" ] || [ ! -s "${voice_source}/index.js" ]; then
            echo '[OHAMLAB] WARNING: voice plugin needs client.js and index.js; skipping voice UI'
        else
            pkg="$(node -e "try { process.stdout.write(require(process.argv[1]).name || '') } catch (_) {}" "${voice_source}/package.json" 2>/dev/null || true)"
            if [ -z "${pkg}" ]; then
                echo '[OHAMLAB] WARNING: voice package name could not be read; skipping voice UI'
            else
                echo "[OHAMLAB] Registering existing voice plugin ${pkg} (no build)"
                ( cd "${DSH_APP_DIR}" && pnpm dsh plugin --profile web add "${voice_source}" ) \
                    && voice_ok=1 \
                    || echo '[OHAMLAB] WARNING: voice plugin registration failed; continuing without microphone icon'
            fi
        fi
    else
        echo '[OHAMLAB] WARNING: valid voice package not found; continuing without microphone icon'
    fi

    # Install what registered successfully. Failure is non-fatal.
    if [ "${brand_ok}" -eq 1 ] || [ "${voice_ok}" -eq 1 ]; then
        ( cd "${DSH_APP_DIR}" && pnpm dsh plugin --profile web install ) \
            || echo '[OHAMLAB] WARNING: profile plugin install failed; Harness startup will continue'
    fi

    # Only add browser bundles for dependencies that really exist in the profile.
    if [ -f "${profile}/package.json" ]; then
        PROFILE_PACKAGE="${profile}/package.json" BRAND_OK="${brand_ok}" VOICE_OK="${voice_ok}" node <<'NODE' || echo '[OHAMLAB] WARNING: could not update browser bundle metadata'
const fs = require('fs');
const file = process.env.PROFILE_PACKAGE;
try {
  const p = JSON.parse(fs.readFileSync(file, 'utf8'));
  p.dsh ??= {};
  p.dsh.profile ??= {};
  p.dsh.profile.bundles ??= [];
  const wanted = [];
  if (process.env.BRAND_OK === '1') wanted.push('@ohamlab/harness-brand');
  if (process.env.VOICE_OK === '1') wanted.push('@ohamlab/harness-voice');
  for (const name of wanted) {
    let manifest;
    try {
      manifest = JSON.parse(fs.readFileSync(require('path').join(require('path').dirname(file), 'node_modules', name, 'package.json'), 'utf8'));
    } catch (e) { console.warn(`[BUNDLE] Cannot inspect ${name}: ${e.message}`); continue; }
    if (!manifest.dsh?.bundle) {
      p.dsh.profile.bundles = p.dsh.profile.bundles.filter(x => x !== name);
      console.log(`[BUNDLE] Keeping ${name} as a plugin, not a profile bundle`);
      continue;
    }
    if (p.dependencies?.[name] && !p.dsh.profile.bundles.includes(name)) {
      p.dsh.profile.bundles.push(name);
      console.log(`[OHAMLAB] Enabled browser bundle: ${name}`);
    }
  }
  fs.writeFileSync(file, JSON.stringify(p, null, 2) + '\n');
} catch (e) {
  console.warn('[OHAMLAB] Could not update profile bundle metadata:', e.message);
  process.exitCode = 1;
}
NODE
        ( cd "${profile}" && pnpm install --no-frozen-lockfile ) \
            || echo '[OHAMLAB] WARNING: profile dependency refresh failed; continuing'
    else
        echo '[OHAMLAB] WARNING: profile package.json missing; plugin bundle activation skipped'
    fi

    echo '[OHAMLAB] Optional OhamLab UI plugin setup finished.'
    return 0
}

# Optional UI plugins must never block the main Harness process.
if [ "$OHAMLAB_REFRESH_PLUGINS" = 0 ] && plugin_bundle_ready '@ohamlab/harness-brand' && plugin_bundle_ready '@ohamlab/harness-voice' && [ -s "${PROFILE_DIR}/node_modules/@ohamlab/harness-brand/lib/client.js" ] && [ -s "${PROFILE_DIR}/node_modules/@ohamlab/harness-voice/client.js" ] && [ -s "${PROFILE_DIR}/node_modules/@ohamlab/harness-voice/index.js" ]; then
    echo '[OHAMLAB] Existing brand and voice plugins verified.'
else
    install_ohamlab_web_plugins || echo '[OHAMLAB] WARNING: optional UI plugin setup failed; continuing startup'
fi

# ============================================================
# REPAIR OPTIONAL SHORTCUTS PLUGIN
# ============================================================
repair_shortcuts_plugin() {
    local profile="${DSH_HOME}/profiles/web"
    local module="${profile}/node_modules/@hytime/dsh-client-ui-shortcuts"
    local entry="${module}/lib/index.js"
    local pkg="${profile}/package.json"
    echo "[OHAMLAB] Checking shortcuts runtime entry: ${entry}"
    if [ -s "${entry}" ]; then
        echo '[OHAMLAB] PASS: shortcuts runtime entry exists'
        return 0
    fi
    echo '[OHAMLAB] Shortcuts entry missing; attempting clean package reinstall'
    if (
        cd "${profile}"
        pnpm add '@hytime/dsh-client-ui-shortcuts@0.1.12' --force --no-frozen-lockfile
    ); then
        if [ -s "${entry}" ]; then
            echo '[OHAMLAB] PASS: shortcuts runtime entry repaired'
            return 0
        fi
    fi
    echo '[OHAMLAB] WARNING: shortcuts remains broken; disabling it'
    cp -f "${pkg}" "${pkg}.before-shortcuts-repair" || true
    PROFILE_PACKAGE="${pkg}" node <<'NODE'
const fs = require('fs');
const file = process.env.PROFILE_PACKAGE;
const p = JSON.parse(fs.readFileSync(file, 'utf8'));
const name = '@hytime/dsh-client-ui-shortcuts';
if (p.dependencies) delete p.dependencies[name];
if (Array.isArray(p.dsh?.profile?.bundles)) {
  p.dsh.profile.bundles =
    p.dsh.profile.bundles.filter(x => x !== name);
}
fs.writeFileSync(file, JSON.stringify(p, null, 2) + '\n');
NODE
    (
        cd "${profile}"
        pnpm install --no-frozen-lockfile
    ) || {
        echo '[OHAMLAB] ERROR: profile install failed after disabling shortcuts'
        return 1
    }
    touch "${profile}/.shortcuts-disabled"
    echo '[OHAMLAB] Shortcuts disabled; OhamLab plugins remain configured.'
}
if plugin_declared "@hytime/dsh-client-ui-shortcuts"; then
repair_shortcuts_plugin || echo '[OHAMLAB] WARNING: shortcuts repair failed; continuing'
fi
# ============================================================
# CORDIS PATCH DIAGNOSTICS
# ============================================================
echo "=========================================================="
echo "[OHAMLAB] Cordis patch diagnostics"
echo "=========================================================="
PROFILE="${DSH_HOME}/profiles/web"
APP="${DSH_APP_DIR}"
PATCH="${PROFILE}/cordis.patch.yml"
if [ -f "${PATCH}" ] &&
   grep -q 'id: ui-brand-ohamlab' "${PATCH}" &&
   ! grep -q 'insert:' "${PATCH}"; then
    cp "${PATCH}" "${PATCH}.invalid-brand-backup"
    cat > "${PATCH}" <<'YAML'
[]
YAML
    echo "[OHAMLAB] Removed invalid old branding patch."
fi
echo "[OHAMLAB] Current profile patch:"
if [ -f "${PATCH}" ]; then
    cat "${PATCH}"
else
    echo "[OHAMLAB] No profile cordis.patch.yml"
fi
# ============================================================
# DETECT PYTHON
# ============================================================
echo "[OHAMLAB] Detecting Python..."
if [ -n "${OHAM_PYTHON:-}" ]; then
    if ! command -v "${OHAM_PYTHON}" >/dev/null 2>&1; then
        echo "[OHAMLAB] ERROR: Configured Python not found: ${OHAM_PYTHON}"
        exit 1
    fi
elif command -v python3 >/dev/null 2>&1; then
    OHAM_PYTHON="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    OHAM_PYTHON="$(command -v python)"
else
    echo "[OHAMLAB] ERROR: Python not installed."
    exit 1
fi
export OHAM_PYTHON
echo "[OHAMLAB] PASS: Python found at ${OHAM_PYTHON}"
"${OHAM_PYTHON}" --version




# ============================================================
# VOICE UI PLUGIN
# ============================================================
# harness-voice is installed directly from vendor/ohamlab/plugins.
# Its committed client.js/index.js and Cordis patch are used as-is.
# Do not run a build step or expect lib/client.js.

# ============================================================
# INSTALL AND START VOICESTUDIO
# ============================================================
install_ohamlab_audio() {
    local repo="${OHAMLAB_AUDIO_HOME}"
    local venv="${OHAMLAB_AUDIO_VENV}"
    local cli="${venv}/bin/ohamlab-voice"
    local log="${DSH_HOME}/logs/voicestudio.log"
    echo
    echo "=========================================================="
    echo "[OHAMLAB AUDIO] Installing OhamLab VoiceStudio"
    echo "=========================================================="
    command -v git >/dev/null 2>&1 || {
        echo '[OHAMLAB AUDIO] WARNING: git unavailable; skipping VoiceStudio'
        return 1
    }
    if [ "$OHAMLAB_REFRESH_AUDIO" = 0 ] && [ -x "$cli" ] && [ -f "${repo}/pyproject.toml" ] && [ -f "${venv}/.ohamlab-audio-ready" ]; then
        echo "[OHAMLAB AUDIO] Existing installation verified."
    else
    if [ -d "${repo}/.git" ]; then
        echo "[OHAMLAB AUDIO] Updating ${repo} from main"
        git -C "${repo}" fetch --depth 1 origin main || {
            echo '[OHAMLAB AUDIO] WARNING: git fetch failed'
            return 1
        }
        git -C "${repo}" checkout -f main >/dev/null 2>&1 || true
        git -C "${repo}" reset --hard origin/main || {
            echo '[OHAMLAB AUDIO] WARNING: git reset failed'
            return 1
        }
    else
        rm -rf "${repo}"
        git clone --depth 1 --branch main \
            "${OHAMLAB_AUDIO_REPO}" "${repo}" || {
            echo '[OHAMLAB AUDIO] WARNING: clone failed'
            return 1
        }
    fi
    [ -f "${repo}/pyproject.toml" ] || {
        echo '[OHAMLAB AUDIO] WARNING: pyproject.toml missing'
        return 1
    }
    if [ ! -x "${venv}/bin/python" ]; then
        "${OHAM_PYTHON}" -m venv "${venv}" || {
            echo '[OHAMLAB AUDIO] WARNING: could not create audio virtualenv'
            return 1
        }
    fi
    "${venv}/bin/python" -m pip install --upgrade pip || {
        echo '[OHAMLAB AUDIO] WARNING: pip upgrade failed'
    }
    "${venv}/bin/python" -m pip install -e "${repo}[tts,asr,studio]" || {
        echo '[OHAMLAB AUDIO] WARNING: VoiceStudio dependencies failed'
        return 1
    }
    touch "${venv}/.ohamlab-audio-ready"
    fi
    [ -x "${cli}" ] || {
        echo '[OHAMLAB AUDIO] WARNING: ohamlab-voice CLI missing'
        return 1
    }
    if [ -n "${AUDIO_PID}" ] && kill -0 "${AUDIO_PID}" 2>/dev/null; then
        echo "[OHAMLAB AUDIO] VoiceStudio already running."
        return 0
    fi
    export GRADIO_SERVER_NAME="${OHAMLAB_AUDIO_HOST}"
    export GRADIO_SERVER_PORT="${OHAMLAB_AUDIO_PORT}"
    export GRADIO_ANALYTICS_ENABLED="False"
    echo "[OHAMLAB AUDIO] Starting studio on ${OHAMLAB_AUDIO_HOST}:${OHAMLAB_AUDIO_PORT}"
    echo "[OHAMLAB AUDIO] Log: ${log}"
    "${cli}" studio \
        --model "${OHAMLAB_AUDIO_MODEL}" \
        --device cpu \
        >"${log}" 2>&1 &
    AUDIO_PID=$!
    trap 'kill -TERM "$AUDIO_PID" 2>/dev/null || true; wait "$AUDIO_PID" 2>/dev/null || true; exit 0' TERM INT
    sleep 5
    if kill -0 "${AUDIO_PID}" 2>/dev/null; then
        echo "[OHAMLAB AUDIO] VoiceStudio process started (PID ${AUDIO_PID})"
        wait "$AUDIO_PID"
    else
        echo '[OHAMLAB AUDIO] WARNING: VoiceStudio exited; check its log'
        AUDIO_PID=""
        return 1
    fi
}
# ============================================================
# VERIFY SEARCH AND AGENT LAB
# ============================================================
echo
echo "[OHAMLAB] Verifying local Search and Agent Lab..."
"${OHAM_PYTHON}" -m pip show ohamlab-agent >/dev/null 2>&1 || {
    echo "[OHAMLAB] ERROR: ohamlab-agent not installed!"
    exit 1
}
"${OHAM_PYTHON}" -m pip show ohamlab-agent-lab >/dev/null 2>&1 || {
    echo "[OHAMLAB] ERROR: ohamlab-agent-lab not installed!"
    exit 1
}
echo "[OHAMLAB] PASS: Search package installed"
echo "[OHAMLAB] PASS: Agent Lab package installed"
# ============================================================
# INSPECT AGENT LAB
# ============================================================
echo
echo "[OHAMLAB] Inspecting Agent Lab installation..."
"${OHAM_PYTHON}" - <<'PY'
from importlib.metadata import distribution
dist = distribution("ohamlab-agent-lab")
print("[OHAMLAB] Agent Lab version:", dist.version)
top_level = dist.read_text("top_level.txt")
print("[OHAMLAB] Python modules:")
print(top_level or "No top_level.txt available")
print("[OHAMLAB] Registered executable entry points:")
for entry in dist.entry_points:
    if entry.group == "console_scripts":
        print(f"  {entry.name} = {entry.value}")
print("[OHAMLAB] Agent Lab package inspection complete.")
PY
# ============================================================
# VERIFY PYTHON DEPENDENCIES
# ============================================================
echo
echo "[OHAMLAB] Checking Python dependencies..."
"${OHAM_PYTHON}" -m pip check
echo "[OHAMLAB] PASS: Python dependencies verified"
# ============================================================
# VERIFY OHAMLAB CLI
# ============================================================
if command -v ohamlab >/dev/null 2>&1; then
    echo "[OHAMLAB] PASS: OhamLab CLI available"
    command -v ohamlab
else
    echo "[OHAMLAB] WARNING: OhamLab CLI unavailable"
fi
# ============================================================
# OHAMLAB PLUGIN DIAGNOSTICS
# ============================================================
diagnose_ohamlab_plugins() (
    set +e
    set +u
    set +o pipefail
    local profile="${DSH_HOME}/profiles/web"
    local brand="/app/ohamlab/plugins/harness-brand"
    local voice="/app/ohamlab/plugins/harness-voice"
    echo
    echo "=========================================================="
    echo "[PLUGIN DEBUG] OhamLab plugin diagnostics"
    echo "=========================================================="
    echo
    echo "[PLUGIN DEBUG] Plugin source directories"
    for dir in "${brand}" "${voice}"; do
        if [ -f "${dir}/package.json" ]; then
            echo "[PLUGIN DEBUG] PASS: ${dir}"
        else
            echo "[PLUGIN DEBUG] WARNING: Missing ${dir}"
        fi
    done
    echo
    echo "[PLUGIN DEBUG] Profile dependencies and bundles"
    if [ -f "${profile}/package.json" ]; then
        PROFILE_PACKAGE="${profile}/package.json" node <<'NODE'
const fs = require('fs');
const p = JSON.parse(fs.readFileSync(process.env.PROFILE_PACKAGE, 'utf8'));
for (const name of [
  '@ohamlab/harness-brand',
  '@ohamlab/harness-voice'
]) {
  console.log(name, {
    dependency: p.dependencies?.[name] ?? null,
    bundle: p.dsh?.profile?.bundles?.includes(name) ?? false
  });
}
NODE
    else
        echo "[PLUGIN DEBUG] Profile package.json missing"
    fi
    echo
    echo "[PLUGIN DEBUG] Installed plugin links"
    for plugin in harness-brand harness-voice; do
        local target="${profile}/node_modules/@ohamlab/${plugin}"
        if [ -e "${target}/package.json" ]; then
            echo "[PLUGIN DEBUG] PASS: ${plugin}"
            readlink -f "${target}"
        else
            echo "[PLUGIN DEBUG] FAIL: ${plugin} not resolved"
        fi
    done
    echo
    echo "[PLUGIN DEBUG] Plugin client files"
    for file in \
        "${brand}/lib/client.js" \
        "${voice}/client.js" \
        "${voice}/index.js" \
        "${voice}/cordis.patch.yml" \
        "${voice}/cordis.patch.yaml"; do
        if [ -s "${file}" ]; then
            echo "[PLUGIN DEBUG] PASS: ${file}"
            wc -c "${file}"
        else
            echo "[PLUGIN DEBUG] Not present: ${file}"
        fi
    done
    echo
    echo "[PLUGIN DEBUG] DSH plugin list"
    (
        cd "${DSH_APP_DIR}"
        pnpm dsh plugin --profile web list
    ) 2>&1
    echo
    echo "[PLUGIN DEBUG] Effective configuration"
    (
        cd "${DSH_APP_DIR}"
        timeout 30s pnpm dsh --profile web --dump-config
    ) 2>&1 | grep -iE -C 4 \
        'ohamlab|harness-brand|harness-voice|error|plugin' \
        | head -120
    echo
    echo "[PLUGIN DEBUG] Diagnostics complete"
)
if [ "$OHAMLAB_DEBUG" = 1 ]; then
diagnose_ohamlab_plugins || {
    echo "[OHAMLAB] WARNING: Plugin diagnostics encountered an error"
}
fi
# ============================================================
# CONFIGURE DSH PROVIDERS
# ============================================================
echo
echo "=========================================================="
echo "[OHAMLAB] Configuring DSH providers"
echo "=========================================================="
SETTINGS_FILE="${DSH_HOME}/settings.yaml"
cat > "${SETTINGS_FILE}" <<'EOF'
# ============================================================
# DeepSeek Harness - LLM Provider Pool
# ============================================================
llm-pi-ai:
  providers:
    HF:
      displayName: HUGGUN
      api: openai-completions
      baseURL: https://rahul7star-Qwen3-9B.hf.space/v1
      apiKeyEnv: HF_TOKEN
      timeoutMs: 120000
      models:
        - id: Qwen3-9B
    HFQWEN:
      displayName: HUGGUN-Xing
      api: openai-completions
      baseURL: https://rahul7star-xing4-0-29b-a4b.hf.space/v1
      apiKeyEnv: HF_TOKEN
      timeoutMs: 120000
      models:
        - id: Xing
    HFQWENX:
      displayName: HUGGUN-XingXX
      api: openai-completions
      baseURL: https://rahul7star-xing4-0-29b-a4b.hf.space/v1/chat/completions
      apiKeyEnv: HF_TOKEN
      timeoutMs: 120000
      models:
        - id: Xing
    kilo:
      displayName: Kilo Free
      api: openai-completions
      baseURL: https://api.kilo.ai/api/gateway
      apiKeyEnv: DASHSCOPE_API_KEY
      timeoutMs: 120000
      models:
        - id: nvidia/nemotron-3-ultra-550b-a55b:free
        - id: stepfun/step-3.7-flash:free
        - id: nvidia/nemotron-3-super-120b-a12b:free
        - id: nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free
        - id: poolside/laguna-s-2.1:free
        - id: poolside/laguna-xs-2.1:free
        - id: cohere/north-mini-code:free
        - id: openrouter/free
        - id: tencent/hy3:free
        - id: nvidia/nemotron-3.5-lightning:free
        - id: liquid/lfm-2.5-2.6b:free
    ovh:
      displayName: ALIBABA NEW
      api: openai-completions
      baseURL: https://dashscope-intl.aliyuncs.com/compatible-mode/v1
      apiKeyEnv: DASHSCOPE_API_KEY
      timeoutMs: 120000
      models:
        - id: kimi-k3
        - id: qwen3-coder-flash
        - id: qwen3.5-27b
        - id: qwen3-235b-a22b-thinking-2507
        - id: qwen-plus-2025-07-28
        - id: qwen3.6-plus
        - id: glm-5.2
        - id: glm-5.3
        - id: deepseek-v4-pro-0813
        - id: qwen3.6-flash
        - id: qwen3-vl-plus-2025-09-23
        - id: Mistral-7B-Instruct-v0.3
    nvidia:
      displayName: NVIDIA NIM
      api: openai-completions
      baseURL: https://integrate.api.nvidia.com/v1
      apiKeyEnv: NVIDIA_API_KEY
      timeoutMs: 120000
      models:
        - id: nvidia/nemotron-3.5-lightning-30b-a3b
        - id: nvidia/nemotron-3.5-super-vl-120b-a12b
        - id: z-ai/glm-5.3
        - id: moonshotai/kimi-k3
        - id: nvidia/nemotron-3-ultra-550b-a55bopenai/gpt-oss-safeguard-20b
        - id: meta/muse-glimmer-30b
        - id: nvidia/nemotron-3-ultra-550b-a55b
        - id: nvidia/nemotron-3-nano-omni-30b-a3b-reasoning
        - id: nvidia/nemotron-3-super-120b-a12b
        - id: qwen/qwen3.8-27b
    dashscope_deepseek:
      displayName: Alibaba DeepSeek V4 Flash
      api: openai-completions
      baseURL: https://dashscope-intl.aliyuncs.com/compatible-mode/v1
      apiKeyEnv: DASHSCOPE_API_KEY
      timeoutMs: 120000
      models:
        - id: qwen3-vl-32b-thinking
        - id: deepseek-v4-flash
        - id: qwen3.8-max
        - id: qwen3-max
        - id: glm-5.1
        - id: qwen3.7-plus
    openrouter:
      displayName: OpenRouter - Dynamic Free
      api: openai-completions
      baseURL: https://openrouter.ai/api/v1
      apiKeyEnv: OPENROUTER_API_KEY
      timeoutMs: 120000
      models:
        - id: openrouter/free
        - id: nvidia/nemotron-3-ultra-550b-a55b:free
        - id: qwen/qwen3-coder:free
    huggingface:
      displayName: Hugging Face Router
      api: openai-completions
      baseURL: https://router.huggingface.co/v1
      apiKeyEnv: HF_TOKEN
      timeoutMs: 120000
      models:
        - id: openai/gpt-oss-120b
        - id: openai/gpt-oss-20b
    dashscope_qwen_flash_next:
      displayName: Qwen 3.8 Flash Next
      api: openai-completions
      baseURL: https://dashscope-intl.aliyuncs.com/api/v2/apps/protocols/compatible-mode/v1
      apiKeyEnv: DASHSCOPE_API_KEY
      timeoutMs: 120000
      models:
        - id: Qwen/Qwen3.8-Flash-Next
    qwen:
      displayName: Qwen 3.8 Flash Next
      api: openai-completions
      baseURL: https://pnywsahxhac1qjbo.us-east-2.aws.endpoints.huggingface.cloud/v1
      apiKeyEnv: HF_TOKEN
      timeoutMs: 120000
      models:
        - id: Qwen/Qwen3.8-Flash-Next
    llama:
      displayName: LFM2.5 Local
      api: openai-completions
      baseURL: http://127.0.0.1:8000/v1
      apiKeyEnv: LLAMA_API_KEY
      timeoutMs: 120000
      models:
        - id: LFM2.5
agent-default-model:
  provider: HF
  model: Qwen3-9B
EOF
chmod 600 "${SETTINGS_FILE}"
echo "[DSH] Settings file: ${SETTINGS_FILE}"
echo "[DSH] Provider pool configured"
echo "[DSH] Default model: HF / Qwen3-9B"
# ============================================================
# VERIFY NGINX
# ============================================================
echo "[OHAMLAB] Checking Nginx..."
nginx -t
# ============================================================
# START NGINX
# ============================================================
echo "[OHAMLAB] Starting Nginx..."
nginx
# ============================================================
# START HOURLY BACKUP WORKER
# ============================================================
hourly_backup &
BACKUP_PID=$!
# ============================================================
# GRACEFUL SHUTDOWN
# ============================================================
shutdown() {
    echo "[OHAMLAB] Shutdown requested."
    trap - TERM INT
    if [ -n "${BACKUP_PID}" ]; then
        kill "${BACKUP_PID}" 2>/dev/null || true
        wait "${BACKUP_PID}" 2>/dev/null || true
    fi
    if [ -n "${AUDIO_PID}" ]; then
        kill -TERM "${AUDIO_PID}" 2>/dev/null || true
        wait "${AUDIO_PID}" 2>/dev/null || true
    fi
    if [ -n "${HARNESS_PID}" ]; then
        kill -TERM "${HARNESS_PID}" 2>/dev/null || true
        wait "${HARNESS_PID}" 2>/dev/null || true
    fi
    nginx -s quit 2>/dev/null || true
    backup_sessions || {
        echo "[OHAMLAB] WARNING: Final backup failed."
    }
    echo "[OHAMLAB] Shutdown complete."
    exit 0
}
trap shutdown TERM INT
# ============================================================
# LAUNCH OHAMLAB HARNESS
# ============================================================
echo "=========================================================="
echo "[OHAMLAB] Launching OhamLab Harness..."
echo "=========================================================="
repair_ohamlab_bundles
log_stage "Launching Harness"
ohamlab-harness start &
HARNESS_PID=$!
# Run optional audio setup separately; exec the service in the worker so
# the parent can terminate it using the tracked PID.
( install_ohamlab_audio ) &
AUDIO_PID=$!
set +e
wait "${HARNESS_PID}"
HARNESS_STATUS=$?
set -e
# ============================================================
# CLEANUP AFTER HARNESS EXIT
# ============================================================
echo "[OHAMLAB] Harness stopped."
if [ -n "${AUDIO_PID}" ]; then
    kill -TERM "${AUDIO_PID}" 2>/dev/null || true
    wait "${AUDIO_PID}" 2>/dev/null || true
fi
kill "${BACKUP_PID}" 2>/dev/null || true
wait "${BACKUP_PID}" 2>/dev/null || true
backup_sessions || true
echo "[OHAMLAB] Harness exit status: ${HARNESS_STATUS}"
exit "${HARNESS_STATUS}"
