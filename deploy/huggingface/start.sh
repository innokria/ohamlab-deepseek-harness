#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# OHAMLAB HARNESS CONFIGURATION
# ============================================================

export OHAMLAB_HARNESS_HOME="${OHAMLAB_HARNESS_HOME:-/app/ohamlab-harness}"
# Keep active DSH data on a POSIX filesystem. HF bucket FUSE does not
# support hard-link operations used by the session journal.
export DSH_HOME=/data/dsh
export OHAMLAB_PERSISTENT_DSH_HOME=/data/dsh
export DSH_HOST="${DSH_HOST:-127.0.0.1}"
export DSH_PORT="${DSH_PORT:-3080}"
export PORT="${PORT:-7860}"

INSTALL_MARKER="${DSH_HOME}/.ohamlab-installed-v2"
export HARNS_BRAND_NAME="OhamLab"


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

# Harness session path
SESSION_DIR="${DSH_HOME}/sessions"

# Active sessions use local filesystem to support hard links
LOCAL_SESSION_DIR="${OHAMLAB_LOCAL_SESSION_DIR:-/tmp/ohamlab-dsh-sessions}"

# Persistent backup on Hugging Face storage
BACKUP_DIR="${OHAMLAB_PERSISTENT_DSH_HOME}/session-backup"
BACKUP_FILE="${BACKUP_DIR}/sessions.tar.gz"

# Backup every hour
BACKUP_INTERVAL=3600

BACKUP_PID=""
HARNESS_PID=""

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
# USE THE PERSISTENT PROFILE DIRECTLY (NO /tmp PROFILE COPY)
# ============================================================
echo "[OHAMLAB] DSH_HOME: ${DSH_HOME}"
echo "[OHAMLAB] Standard CLI profile: ${DSH_HOME}/profiles/web"
echo "[OHAMLAB] Requested alternate path: ${DSH_HOME}/web/profile"
# The DSH CLI has demonstrably resolved profiles/web. Do not assume that
# web/profile is a supported profile location or overwrite it.
if [ -f "${DSH_HOME}/web/profile/package.json" ]; then
    echo '[OHAMLAB] NOTE: /data/dsh/web/profile exists; CLI still uses profiles/web unless configured otherwise.'
fi
# HF storage cannot hard-link session journal files. Keep only sessions local.
# Never delete or replace an existing persistent sessions directory automatically.
if [ -L "${SESSION_DIR}" ]; then
    if [ "$(readlink -f "${SESSION_DIR}")" != "$(readlink -f "${LOCAL_SESSION_DIR}")" ]; then
        echo "[OHAMLAB] ERROR: Existing sessions symlink points elsewhere: ${SESSION_DIR}"
        exit 1
    fi
elif [ -e "${SESSION_DIR}" ]; then
    echo "[OHAMLAB] ERROR: ${SESSION_DIR} is an existing directory on HF storage."
    echo '[OHAMLAB] Existing data was NOT changed. Move it aside after backing it up, then restart.'
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

python --version
ohamlab-harness --version

command -v tar >/dev/null || {
    echo "[OHAMLAB] ERROR: tar is not installed."
    exit 1
}

# ============================================================
# SESSION BACKUP FUNCTION
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
# RESTORE SESSIONS ON STARTUP
# ============================================================

restore_sessions() {

    if [ ! -f "${BACKUP_FILE}" ]; then

        echo "[OHAMLAB] No previous session backup found."
        return 0

    fi

    if [ -z "$(find "${LOCAL_SESSION_DIR}" \
        -mindepth 1 -maxdepth 1 -print -quit)" ]; then

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
# AUTOMATIC HOURLY BACKUP
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



## TEST
# ==========================================================
# 2b. Optional plugins
# ==========================================================

echo
echo "=========================================================="
echo "[2b/8] Installing optional plugins"
echo "=========================================================="

export PROBE_DISABLED=1


# Resolve the real Harness app before running any DSH plugin command.
resolve_dsh_app_dir() {
    local root
    for root in \
        "${OHAMLAB_HARNESS_HOME}/app" \
        "${OHAMLAB_HARNESS_HOME}" \
        /app/deepseek-harness \
        /app/deepseek-harness/app; do
        if [ -f "${root}/package.json" ] && [ -f "${root}/apps/cli/src/bin.ts" ]; then
            printf '%s\n' "${root}"
            return 0
        fi
    done
    return 1
}

if ! DSH_APP_DIR="$(resolve_dsh_app_dir)"; then
    echo '[OHAMLAB] ERROR: Cannot locate Harness source with apps/cli/src/bin.ts'
    exit 1
fi
export DSH_APP_DIR
echo "[OHAMLAB] Harness app directory: ${DSH_APP_DIR}"
PROFILE_DIR="${DSH_HOME}/profiles/web"


PLUGINS=(
    "@hytime/dsh-client-ui-shortcuts@0.1.12"
    "dshmarket"
    "dsh-skill-picker"
    "@deepseek-ai/dsh-mcp-client"
    

    # OhamLab Agent Lab — DSH plugin v2.0
    "https://github.com/innokria/dsh-ohamlab-agent-lab.git#2.0"
    
)


# ----------------------------------------------------------
# Remove known incompatible plugins
# ----------------------------------------------------------

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

    echo "[PLUGIN] Disabling: ${PLUGIN}"

    (
        cd "${DSH_APP_DIR}" &&
        pnpm dsh plugin --profile web remove "${PLUGIN}"
    ) >/tmp/plugin-remove.log 2>&1 || true

    rm -rf \
        "${PROFILE_DIR}/node_modules/${PLUGIN}" \
        "${PROFILE_DIR}/node_modules/.pnpm"/"${PLUGIN}"* \
        2>/dev/null || true

done


# ----------------------------------------------------------
# Install optional plugins
# ----------------------------------------------------------

for PLUGIN in "${PLUGINS[@]}"; do

    echo
    echo "[PLUGIN] Installing: ${PLUGIN}"

    if (
        cd "${DSH_APP_DIR}" &&
        pnpm dsh plugin --profile web add "${PLUGIN}"
    ); then

        echo "[PLUGIN] OK: ${PLUGIN}"

    else

        echo "[PLUGIN] WARNING: failed to install ${PLUGIN}"
        echo "[PLUGIN] Continuing without ${PLUGIN}"

    fi

done


# ----------------------------------------------------------
# Approve optional dependencies
# ----------------------------------------------------------

echo
echo "[PLUGIN] Approving optional build scripts..."

(
    cd "${DSH_APP_DIR}" &&
    pnpm approve-builds --all
) >/tmp/plugin-approve.log 2>&1 || true





# Branding is installed below by install_ohamlab_web_plugins().


## TEST
# ============================================================
# INSTALL / REPAIR OHAMLAB WEB BRANDING PLUGIN
# ============================================================
# Plugin sources live in vendor/ohamlab/plugins, not in the Harness
# application root. Keep startup non-fatal if an optional plugin fails.

# DSH_APP_DIR was resolved before optional plugin installation.

resolve_ohamlab_plugin() {
    local name="$1" root
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

# The working Docker image takes branding from release 2.0. Do not silently
# replace it with a different revision. Voice may be absent from that tag.
fetch_ohamlab_plugin() {
    local name="$1" ref="$2" repo="${OHAMLAB_REPO_URL:-https://github.com/innokria/ohamlab-deepseek-harness.git}"
    local dest="/app/ohamlab/plugins/${name}" tmp
    tmp="$(mktemp -d /tmp/ohamlab-plugin.XXXXXX)"
    echo "[OHAMLAB] Fetching ${name} at ${ref}"
    if ( cd "${tmp}" && git init -q && git remote add origin "${repo}" && \
         git config core.sparseCheckout true && \
         printf 'vendor/ohamlab/plugins/%s/\n' "${name}" > .git/info/sparse-checkout && \
         git fetch -q --depth 1 origin "${ref}" && \
         git checkout -q FETCH_HEAD && \
         test -f "vendor/ohamlab/plugins/${name}/package.json" ); then
        mkdir -p /app/ohamlab/plugins
        cp -a "${tmp}/vendor/ohamlab/plugins/${name}" "${dest}"
        rm -rf "${tmp}"
        return 0
    fi
    rm -rf "${tmp}"
    return 1
}

install_ohamlab_web_plugins() {
    local plugin="harness-brand"
    local source="" pkg="@ohamlab/harness-brand"
    local profile="${DSH_HOME}/profiles/web"
    local profile_package="${profile}/package.json"

    echo "[OHAMLAB] Installing optional OhamLab branding plugin (best-effort)..."

    if ! command -v pnpm >/dev/null 2>&1; then
        echo "[OHAMLAB] WARNING: pnpm unavailable; skipping branding plugin"
        return 0
    fi

    if ! mkdir -p "${profile}"; then
        echo "[OHAMLAB] WARNING: cannot create web profile; skipping branding plugin"
        return 0
    fi

    # harness-voice is deliberately disabled. Its client bundle currently
    # loads without registering @ohamlab/harness-voice in __ModuleLoader__,
    # which causes a client-modules loader failure and can break the UI.
    echo "[OHAMLAB] Disabling known-broken optional plugin: @ohamlab/harness-voice"
    if [ -f "${profile_package}" ]; then
        if ! PROFILE_PACKAGE="${profile_package}" node <<'NODE'
const fs = require('fs');
const file = process.env.PROFILE_PACKAGE;
try {
  const p = JSON.parse(fs.readFileSync(file, 'utf8'));
  const name = '@ohamlab/harness-voice';
  if (p.dependencies) delete p.dependencies[name];
  if (p.optionalDependencies) delete p.optionalDependencies[name];
  if (p.devDependencies) delete p.devDependencies[name];
  if (p.dsh?.profile && Array.isArray(p.dsh.profile.bundles)) {
    p.dsh.profile.bundles = p.dsh.profile.bundles.filter(x => x !== name);
  }
  fs.writeFileSync(file, JSON.stringify(p, null, 2) + '\n');
} catch (e) {
  console.error('[OHAMLAB] WARNING: could not remove voice from profile metadata:', e.message);
  process.exitCode = 1;
}
NODE
        then
            echo "[OHAMLAB] WARNING: voice metadata cleanup failed; continuing startup"
        fi
    else
        echo "[OHAMLAB] WARNING: profile package.json missing; cannot clean voice dependency"
    fi

    # Remove any stale installed link so the runtime cannot discover the
    # broken client bundle from a previous deployment.
    if ! rm -rf "${profile}/node_modules/@ohamlab/harness-voice"; then
        echo "[OHAMLAB] WARNING: could not remove stale voice module; continuing"
    fi

    if ! source="$(resolve_ohamlab_plugin "${plugin}")"; then
        if fetch_ohamlab_plugin "${plugin}" "${OHAMLAB_BRAND_REF:-2.0}"; then
            source="/app/ohamlab/plugins/${plugin}"
        else
            echo "[OHAMLAB] WARNING: ${pkg} source unavailable; continuing without branding"
            return 0
        fi
    fi

    echo "[OHAMLAB] ${pkg} source: ${source}"

    if [ ! -s "${source}/package.json" ]; then
        echo "[OHAMLAB] WARNING: ${pkg} package.json missing; skipping"
        return 0
    fi

    if ! PLUGIN_PACKAGE="${source}/package.json" node -e '
      const fs=require("fs");
      const p=JSON.parse(fs.readFileSync(process.env.PLUGIN_PACKAGE,"utf8"));
      console.log(JSON.stringify({name:p.name,version:p.version,dsh:p.dsh,exports:p.exports},null,2));
    '; then
        echo "[OHAMLAB] WARNING: ${pkg} metadata invalid; skipping"
        return 0
    fi

    if [ ! -s "${source}/lib/client.js" ]; then
        echo "[OHAMLAB] Building ${pkg} client artifact"
        if ! ( cd "${source}" && pnpm install --no-frozen-lockfile && pnpm run build ); then
            echo "[OHAMLAB] WARNING: ${pkg} build failed; continuing without branding"
            return 0
        fi
    fi

    if [ ! -s "${source}/lib/client.js" ]; then
        echo "[OHAMLAB] WARNING: ${pkg} lib/client.js missing; skipping"
        return 0
    fi

    if ! ( cd "${DSH_APP_DIR}" && pnpm dsh plugin --profile web add "${source}" ); then
        echo "[OHAMLAB] WARNING: failed to register ${pkg}; continuing startup"
        return 0
    fi

    if ! ( cd "${DSH_APP_DIR}" && pnpm dsh plugin --profile web install ); then
        echo "[OHAMLAB] WARNING: profile plugin install failed; continuing with existing installation"
    fi

    if [ ! -f "${profile_package}" ]; then
        echo "[OHAMLAB] WARNING: ${profile_package} missing; skipping bundle activation"
        return 0
    fi

    if ! PROFILE_PACKAGE="${profile_package}" node <<'NODE'
const fs = require('fs');
const file = process.env.PROFILE_PACKAGE;
try {
  const p = JSON.parse(fs.readFileSync(file, 'utf8'));
  p.dsh ??= {};
  p.dsh.profile ??= {};
  p.dsh.profile.bundles ??= [];
  const brand = '@ohamlab/harness-brand';
  const voice = '@ohamlab/harness-voice';
  p.dsh.profile.bundles = p.dsh.profile.bundles.filter(x => x !== voice);
  if (p.dependencies) delete p.dependencies[voice];
  if (p.dependencies?.[brand] && !p.dsh.profile.bundles.includes(brand)) {
    p.dsh.profile.bundles.push(brand);
  }
  fs.writeFileSync(file, JSON.stringify(p, null, 2) + '\n');
  console.log('[OHAMLAB] Active OhamLab bundles:', p.dsh.profile.bundles.filter(x => x.startsWith('@ohamlab/')));
} catch (e) {
  console.error('[OHAMLAB] WARNING: bundle metadata update failed:', e.message);
  process.exitCode = 1;
}
NODE
    then
        echo "[OHAMLAB] WARNING: could not update branding bundle metadata; continuing"
    fi

    if ! ( cd "${profile}" && pnpm install --no-frozen-lockfile ); then
        echo "[OHAMLAB] WARNING: profile dependency install failed; continuing with existing node_modules"
    fi

    if ! ( cd "${DSH_APP_DIR}" && pnpm dsh plugin --profile web list ); then
        echo "[OHAMLAB] WARNING: plugin list command failed; continuing"
    fi

    echo "[OHAMLAB] Optional branding setup finished."
    return 0
}

# Optional plugin setup must never abort Harness startup.
if ! install_ohamlab_web_plugins; then
    echo "[OHAMLAB] WARNING: branding setup failed unexpectedly; continuing startup"
fi

# ============================================================
# REPAIR OPTIONAL SHORTCUTS PLUGIN BEFORE HARNESS BOOT
# ============================================================
# A profile dependency can be present even when its exported entrypoint
# is absent. In that case the DSH server crashes during module loading.
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
    if ( cd "${profile}" && pnpm add '@hytime/dsh-client-ui-shortcuts@0.1.12' --force --no-frozen-lockfile ); then
        if [ -s "${entry}" ]; then
            echo '[OHAMLAB] PASS: shortcuts runtime entry repaired'
            return 0
        fi
    fi
    # This is an optional UI plugin. Disable only this broken package,
    # preserving brand/voice and all other profile configuration.
    echo '[OHAMLAB] WARNING: shortcuts remains broken; disabling it to prevent DSH crash'
    cp -f "${pkg}" "${pkg}.before-shortcuts-repair" || true
    PROFILE_PACKAGE="${pkg}" node <<'NODE'
const fs = require('fs');
const file = process.env.PROFILE_PACKAGE;
const p = JSON.parse(fs.readFileSync(file, 'utf8'));
const name = '@hytime/dsh-client-ui-shortcuts';
if (p.dependencies) delete p.dependencies[name];
if (Array.isArray(p.dsh?.profile?.bundles)) {
  p.dsh.profile.bundles = p.dsh.profile.bundles.filter(x => x !== name);
}
fs.writeFileSync(file, JSON.stringify(p, null, 2) + '\n');
NODE
    ( cd "${profile}" && pnpm install --no-frozen-lockfile ) || {
        echo '[OHAMLAB] ERROR: profile install failed after disabling broken shortcuts'
        return 1
    }
    echo '[OHAMLAB] Shortcuts disabled; continuing with remaining configured plugins'
}
if ! repair_shortcuts_plugin; then
    echo '[OHAMLAB] WARNING: shortcuts repair failed; continuing startup'
fi

# Persist repaired profile metadata for the next Space restart. Avoid copying
# node_modules back to the bucket (large and full of symlinks).
if [ -f "${DSH_HOME}/profiles/web/package.json" ]; then
    mkdir -p "${OHAMLAB_PERSISTENT_DSH_HOME}/profiles/web"
    for f in package.json cordis.yml cordis.patch.yml pnpm-lock.yaml pnpm-workspace.yaml; do
        if [ -f "${DSH_HOME}/profiles/web/${f}" ]; then
            cp -f "${DSH_HOME}/profiles/web/${f}" "${OHAMLAB_PERSISTENT_DSH_HOME}/profiles/web/${f}" || true
        fi
    done
fi




# ============================================================
# OHAMLAB BRANDING - CORDIS PATCH
# ============================================================

# ============================================================
# OHAMLAB BRANDING - CORDIS PATCH INVESTIGATION
# ============================================================

echo "=========================================================="
echo "[OHAMLAB] Investigating Cordis insertion syntax"
echo "=========================================================="

PROFILE="${DSH_HOME}/profiles/web"
APP="${DSH_APP_DIR:-/app/ohamlab-harness/app}"
PATCH="${PROFILE}/cordis.patch.yml"

# Remove only the invalid patch we previously generated.
if [ -f "${PATCH}" ] &&
   grep -q 'id: ui-brand-ohamlab' "${PATCH}" &&
   ! grep -q 'insert:' "${PATCH}"; then

    cp "${PATCH}" "${PATCH}.invalid-brand-backup"

    cat > "${PATCH}" <<'YAML'
[]
YAML

    echo "[OHAMLAB] Removed invalid branding patch."
fi

echo "[OHAMLAB] Searching installed DSH source for patch syntax..."

grep -RInE \
  --include='*.ts' \
  --include='*.yml' \
  --include='*.yaml' \
  --exclude-dir=node_modules \
  'insert:|before:|after:|patch: entry|insertBefore|insertAfter' \
  "${APP}/apps" \
  "${APP}/packages" \
  2>/dev/null | head -100 || true

echo "[OHAMLAB] Current patch:"
cat "${PATCH}"

echo "=========================================================="

echo "=========================================================="
# ------------------------------------------------------------
# 4. Verify local Search and Agent Lab packages
# ------------------------------------------------------------
# ------------------------------------------------------------
# Detect Python interpreter
# ------------------------------------------------------------

echo "[OHAMLAB] Starting Harness..."




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
    echo "[OHAMLAB] ERROR: Neither python3 nor python is installed!"
    exit 1
fi

echo "[OHAMLAB] PASS: Python found at ${OHAM_PYTHON}"

"${OHAM_PYTHON}" --version
echo
echo "[OHAMLAB] Verifying local Search and Agent Lab..."

if [ ! -x "${OHAM_PYTHON}" ]; then
    echo "[OHAMLAB] ERROR: Python environment not found: ${OHAM_PYTHON}"
    exit 1
fi

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

# ------------------------------------------------------------
# 5. Inspect Agent Lab Python entry points
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# 6. Verify Python dependencies
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Checking Python dependencies..."

if "${OHAM_PYTHON}" -m pip check; then
    echo "[OHAMLAB] PASS: Python dependencies verified"
else
    echo "[OHAMLAB] WARNING: Python dependency check reported issues; continuing startup"
fi

# ------------------------------------------------------------
# 7. Verify OhamLab CLI
# ------------------------------------------------------------

if command -v ohamlab >/dev/null 2>&1; then
    echo "[OHAMLAB] PASS: OhamLab CLI available"
    command -v ohamlab
else
    echo "[OHAMLAB] WARNING: OhamLab CLI unavailable"
fi



# ============================================================
# OHAMLAB BRANDING DIAGNOSTICS
# Runs automatically before Harness starts
# Read-only: does not change plugin configuration
# ============================================================

diagnose_ohamlab_branding() (
    set +e
    set +u
    set +o pipefail

    echo
    echo "=========================================================="
    echo "[BRAND DEBUG] STARTING OHAMLAB BRANDING DIAGNOSTICS"
    echo "=========================================================="

    BRAND_DIR="/app/ohamlab/plugins/harness-brand"
    PROFILE_DIR="${DSH_HOME:-/data/dsh}/profiles/web"
    APP_DIR="${DSH_APP_DIR:-/app/ohamlab-harness/app}"

    echo
    echo "[BRAND DEBUG] 1. IMPORTANT PATHS"
    echo "DSH_HOME=${DSH_HOME:-unset}"
    echo "OHAMLAB_HARNESS_HOME=${OHAMLAB_HARNESS_HOME:-unset}"
    echo "DSH_APP_DIR=${APP_DIR}"
    echo "BRAND_DIR=${BRAND_DIR}"
    echo "PROFILE_DIR=${PROFILE_DIR}"

    echo
    echo "[BRAND DEBUG] 2. BRAND SOURCE"

    if [ -f "${BRAND_DIR}/package.json" ]; then
        echo "[BRAND DEBUG] PASS: Branding package exists"
        ls -la "${BRAND_DIR}"
    else
        echo "[BRAND DEBUG] FAIL: Branding source missing"
    fi

    echo
    echo "[BRAND DEBUG] 3. BRAND PACKAGE METADATA"

    if [ -f "${BRAND_DIR}/package.json" ]; then
        BRAND_PACKAGE="${BRAND_DIR}/package.json" node <<'NODE'
const fs = require("fs");
const p = JSON.parse(fs.readFileSync(process.env.BRAND_PACKAGE, "utf8"));

console.log(JSON.stringify({
    name: p.name,
    version: p.version,
    type: p.type,
    main: p.main,
    exports: p.exports,
    dsh: p.dsh,
    scripts: p.scripts
}, null, 2));
NODE
    fi

    echo
    echo "[BRAND DEBUG] 4. COMPILED BRAND ARTIFACTS"

    for file in \
        "${BRAND_DIR}/lib/index.js" \
        "${BRAND_DIR}/lib/client.js"; do

        if [ -s "${file}" ]; then
            echo "[BRAND DEBUG] PASS: ${file}"
            ls -lh "${file}"
        else
            echo "[BRAND DEBUG] FAIL: Missing or empty ${file}"
        fi
    done

    echo
    echo "[BRAND DEBUG] 5. PROFILE PACKAGE"

    if [ -f "${PROFILE_DIR}/package.json" ]; then
        PROFILE_PACKAGE="${PROFILE_DIR}/package.json" node <<'NODE'
const fs = require("fs");
const p = JSON.parse(fs.readFileSync(process.env.PROFILE_PACKAGE, "utf8"));

console.log("Profile name:", p.name);
console.log("Dependencies:", JSON.stringify(p.dependencies, null, 2));
console.log("Bundles:", JSON.stringify(p.dsh?.profile?.bundles, null, 2));

for (const name of ["@ohamlab/harness-brand"]) {
    console.log(name, {
        installed: Boolean(p.dependencies?.[name]),
        bundle: Boolean(p.dsh?.profile?.bundles?.includes(name))
    });
}
NODE
    else
        echo "[BRAND DEBUG] FAIL: Web profile package.json missing"
    fi

    echo
    echo "[BRAND DEBUG] 6. PROFILE SYMLINKS"

    for plugin in harness-brand; do
        target="${PROFILE_DIR}/node_modules/@ohamlab/${plugin}"

        if [ -e "${target}/package.json" ]; then
            echo "[BRAND DEBUG] PASS: ${plugin} resolves"
            readlink -f "${target}"
        else
            echo "[BRAND DEBUG] FAIL: ${plugin} does not resolve"
            ls -ld "${target}" 2>&1
        fi
    done

    echo
    echo "[BRAND DEBUG] 7. CORDIS CONFIGURATION"

    for file in \
        "${PROFILE_DIR}/cordis.yml" \
        "${PROFILE_DIR}/cordis.patch.yml"; do

        echo "[BRAND DEBUG] File: ${file}"

        if [ -f "${file}" ]; then
            cat "${file}"
        else
            echo "[BRAND DEBUG] Missing"
        fi
    done

    echo
    echo "[BRAND DEBUG] 8. CLIENT IMPLEMENTATION FILES"

    if [ -d "${BRAND_DIR}" ]; then
        find "${BRAND_DIR}" \
            -maxdepth 4 \
            -type f \
            ! -path '*/node_modules/*' \
            ! -name '*.map' \
            | sort | head -100
    fi

    echo
    echo "[BRAND DEBUG] 9. CLIENT REGISTRATION REFERENCES"

    if [ -d "${BRAND_DIR}" ]; then
        grep -RInE \
            --exclude-dir=node_modules \
            --exclude='*.map' \
            --exclude='*.min.js' \
            'register|inject|mount|onMounted|createRoot|document\.|window\.|logo|branding|fish|client' \
            "${BRAND_DIR}/src" \
            "${BRAND_DIR}/lib/client.js" \
            2>/dev/null | cut -c 1-350 | head -100
    fi

    echo
    echo "[BRAND DEBUG] 10. DSH CLI PLUGIN LIST"

    if [ -f "${APP_DIR}/apps/cli/src/bin.ts" ]; then
        (
            cd "${APP_DIR}" || exit 1
            pnpm dsh plugin --profile web list
        ) 2>&1
    else
        echo "[BRAND DEBUG] FAIL: DSH CLI not found at ${APP_DIR}"
    fi

    echo
    echo "[BRAND DEBUG] 11. DSH EFFECTIVE CONFIGURATION"

    if [ -f "${APP_DIR}/apps/cli/src/bin.ts" ]; then
        (
            cd "${APP_DIR}" || exit 1
            timeout 30s pnpm dsh --profile web --dump-config
        ) 2>&1 | grep -iE \
            -C 5 'ohamlab|harness-brand|error|plugin' \
            | head -120
    fi

    echo
    echo "[BRAND DEBUG] 12. ALTERNATE PROFILE LOCATION"

    if [ -d "${DSH_HOME:-/data/dsh}/web/profile" ]; then
        echo "[BRAND DEBUG] Alternate profile exists:"
        ls -la "${DSH_HOME:-/data/dsh}/web/profile" | head -30
    else
        echo "[BRAND DEBUG] No alternate web/profile directory"
    fi

    echo
    echo "[BRAND DEBUG] 13. BRAND CLIENT CONTENT CHECK"

    if [ -s "${BRAND_DIR}/lib/client.js" ]; then
        echo "[BRAND DEBUG] Client file size:"
        wc -c "${BRAND_DIR}/lib/client.js"

        echo "[BRAND DEBUG] Client imports:"
        grep -oE \
            '(from |import\()["\x27][^"\x27]+' \
            "${BRAND_DIR}/lib/client.js" \
            | head -30
    fi

    echo
    echo "=========================================================="
    echo "[BRAND DEBUG] DIAGNOSTICS FINISHED"
    echo "=========================================================="
    echo
)

echo "[OHAMLAB] Running branding diagnostics before launch..."
diagnose_ohamlab_branding || \
    echo "[OHAMLAB] WARNING: Branding diagnostics encountered an error"


    
echo
echo "=========================================================="
echo "[DSH] Installed web plugins"
echo "=========================================================="

( cd "${DSH_APP_DIR}" && pnpm dsh plugin --profile web list ) 2>&1 || true

# ==========================================================
# 3. Configure DSH providers
# ==========================================================

echo
echo "=========================================================="
echo "[3/8] Configuring DSH providers"
echo "=========================================================="

SETTINGS_FILE="${DSH_HOME}/settings.yaml"

cat > "${SETTINGS_FILE}" <<'EOF'

# ============================================================
# DeepSeek Harness - LLM Provider Pool
# ============================================================

llm-pi-ai:
  providers:

    # ========================================================
    # FREE - NO LOGIN / NO API KEY
    # ========================================================
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

    
    # ========================================================
    # OPENROUTER
    # ========================================================

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

 



    # ========================================================
    # HUGGING FACE
    # ========================================================

    huggingface:
      displayName: Hugging Face Router
      api: openai-completions
      baseURL: https://router.huggingface.co/v1
      apiKeyEnv: HF_TOKEN
      timeoutMs: 120000
      models:
        - id: openai/gpt-oss-120b
        - id: openai/gpt-oss-20b

    # ========================================================
    # QWEN
    # ========================================================

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

    # ========================================================
    # AGNES
    # ========================================================

   

    # ========================================================
    # NVIDIA
    # ========================================================

    

    # ========================================================
    # LOCAL LLAMA.CPP
    # ========================================================

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
echo "[DSH] Default model: groq / openai/gpt-oss-120b"

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

    # Stop backup worker
    if [ -n "${BACKUP_PID}" ]; then

        kill "${BACKUP_PID}" 2>/dev/null || true

        wait "${BACKUP_PID}" 2>/dev/null || true

    fi

    # Stop Harness
    if [ -n "${HARNESS_PID}" ]; then

        kill -TERM "${HARNESS_PID}" 2>/dev/null || true

        wait "${HARNESS_PID}" 2>/dev/null || true

    fi

    # Stop Nginx
    nginx -s quit 2>/dev/null || true

    # Final session backup
    backup_sessions || \
        echo "[OHAMLAB] WARNING: Final backup failed."

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
echo "[OHAMLAB] Launching OhamLab Harness..."

# Paste the full diagnostic block here

ohamlab-harness start &

HARNESS_PID=$!

# Wait for Harness
set +e

wait "${HARNESS_PID}"

HARNESS_STATUS=$?

set -e

# ============================================================
# CLEANUP AFTER HARNESS EXIT
# ============================================================

echo "[OHAMLAB] Harness stopped."

# Stop hourly backup worker
kill "${BACKUP_PID}" 2>/dev/null || true

wait "${BACKUP_PID}" 2>/dev/null || true

# Final backup
backup_sessions || true

echo "[OHAMLAB] Harness exit status: ${HARNESS_STATUS}"

exit "${HARNESS_STATUS}"
