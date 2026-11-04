#!/usr/bin/env bash
set -e

# ==========================================================
# Ensure standard system commands and Bash are discoverable
# ==========================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export SHELL="/bin/bash"
export BASH="/bin/bash"

echo "Checking Bash availability..."

# ==========================================================
# Check common Bash locations
# ==========================================================

if [ -x /bin/bash ]; then
    BASH_PATH="/bin/bash"
elif [ -x /usr/bin/bash ]; then
    BASH_PATH="/usr/bin/bash"
else
    echo "ERROR: Bash executable not found at /bin/bash or /usr/bin/bash"
    exit 1
fi

echo "Bash found at: ${BASH_PATH}"
"${BASH_PATH}" --version

echo
echo "PATH lookup:"
command -v bash || true

echo
echo "Executable details:"
ls -l /usr/bin/bash /bin/bash 2>/dev/null || true

# ==========================================================
# Verify Node.js can spawn Bash
# ==========================================================

echo
echo "Checking Node.js Bash spawning..."

node -e '
const { spawnSync } = require("node:child_process");

const result = spawnSync("bash", ["-lc", "echo BASH_SPAWN_OK"], {
    env: {
        ...process.env,
        PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        SHELL: "/bin/bash",
    },
    encoding: "utf8",
});

if (result.error) {
    console.error("Bash spawn failed:", result.error);
    process.exit(1);
}

if (result.status !== 0) {
    console.error("Bash exited with status:", result.status);
    console.error(result.stderr);
    process.exit(1);
}

console.log(result.stdout.trim());
'

echo
echo "Bash verification completed."

# ==========================================================
# Continue with your existing startup code below this point
# Do not remove your DSH startup, session backup, or Nginx code.
# ==========================================================


# Keep the rest of your existing start.sh below this line

# ==========================================================
# DeepSeek Harness 1.0
# Hugging Face Space
#
# Architecture:
#
# Internet
#    │
#    ▼
# nginx :7860
#    │
#    ▼
# DSH :3080 (127.0.0.1 only)
#    │
#    ├── Western providers
#    ├── Chinese providers
#    ├── OpenRouter models
#    └── Optional providers
#
# SESSION STORAGE:
#
# DSH writes sessions ONLY to local /tmp.
#
# Every 30 seconds:
#
#   /tmp/dsh-sessions
#          │
#          ▼
#     tar.gz archive
#          │
#          ▼
#   /data/dsh/session-backup.tar.gz
#
# On startup:
#
#   /data/dsh/session-backup.tar.gz
#          │
#          ▼
#   /tmp/dsh-sessions
#          │
#          ▼
#       DSH starts
#
# This avoids HF bucket hard-link / ENOTSUP problems while
# preserving the native DSH session files.
# ==========================================================

set -u

export DSH_HOME="${DSH_HOME:-/data/dsh}"
export DSH_PORT="${DSH_PORT:-3080}"
export PORT="${PORT:-7860}"
export DSH_HOST="${DSH_HOST:-127.0.0.1}"
export DSH_TRUSTED_HOST="${DSH_TRUSTED_HOST:-rahul7star-harnes-clone.hf.space}"
export MCP_AUTH_REQUIRED="${MCP_AUTH_REQUIRED:-false}"


# ==========================================================
# Session configuration
# ==========================================================

export DSH_LOCAL_SESSIONS="/tmp/dsh-sessions"

export DSH_SESSION_BACKUP_DIR="${DSH_HOME}/session-backup"

export DSH_SESSION_BACKUP="${DSH_SESSION_BACKUP_DIR}/sessions.tar.gz"

export DSH_SESSION_BACKUP_TMP="/tmp/dsh-session-backup.tar.gz.tmp"

export DSH_SESSION_SYNC_INTERVAL="${DSH_SESSION_SYNC_INTERVAL:-1800}"


echo
echo "=========================================================="
echo "DeepSeek Harness - OhamLab HF Space"
echo "=========================================================="
echo "[DSH] Repository:       innokria/deepseek-harness"
echo "[DSH] Version:          1.0"
echo "[DSH] DSH_HOME:         ${DSH_HOME}"
echo "[DSH] Internal:         ${DSH_HOST}:${DSH_PORT}"
echo "[DSH] Public:           0.0.0.0:${PORT}"
echo "[DSH] Trusted host:     ${DSH_TRUSTED_HOST}"
echo
echo "[SESSION] Local:       ${DSH_LOCAL_SESSIONS}"
echo "[SESSION] HF backup:   ${DSH_SESSION_BACKUP}"
echo "[SESSION] Interval:    ${DSH_SESSION_SYNC_INTERVAL}s"
echo


# ==========================================================
# 1. Prepare persistent + local storage
# ==========================================================

echo "=========================================================="
echo "[1/8] Preparing storage"
echo "=========================================================="

mkdir -p "${DSH_HOME}"

mkdir -p \
    "${DSH_HOME}/profiles" \
    "${DSH_HOME}/plugins" \
    "${DSH_HOME}/workspaces" \
    "${DSH_HOME}/cache" \
    "${DSH_HOME}/logs" \
    "${DSH_HOME}/tmp"

mkdir -p "${DSH_SESSION_BACKUP_DIR}"

# ----------------------------------------------------------
# Sessions MUST use local container storage.
# ----------------------------------------------------------

# rm -rf "${DSH_LOCAL_SESSIONS}"

# mkdir -p "${DSH_LOCAL_SESSIONS}"

# rm -rf "${DSH_HOME}/sessions"

# ln -s "${DSH_LOCAL_SESSIONS}" "${DSH_HOME}/sessions"


mkdir -p "${DSH_HOME}" "${DSH_LOCAL_SESSIONS}"

if [ -L "${DSH_HOME}/sessions" ]; then
    TARGET=$(readlink "${DSH_HOME}/sessions")

    if [ "${TARGET}" != "${DSH_LOCAL_SESSIONS}" ]; then
        echo "[SESSION] ERROR: unexpected sessions symlink: ${TARGET}"
        exit 1
    fi

elif [ -e "${DSH_HOME}/sessions" ]; then
    echo "[SESSION] ERROR: sessions path already exists."
    echo "[SESSION] Back up and migrate it before continuing."
    exit 1

else
    ln -s "${DSH_LOCAL_SESSIONS}" "${DSH_HOME}/sessions"
fi




echo "[DSH] Persistent storage: ${DSH_HOME}"
echo "[DSH] Session storage:     ${DSH_HOME}/sessions -> ${DSH_LOCAL_SESSIONS}"

# ==========================================================
# 1b. Restore previous DSH sessions
# ==========================================================

echo
echo "=========================================================="
echo "[SESSION] Restoring previous sessions"
echo "=========================================================="

if [ -f "${DSH_SESSION_BACKUP}" ]; then

    echo "[SESSION] Backup found:"
    echo "          ${DSH_SESSION_BACKUP}"

    echo "[SESSION] Backup size:"
    ls -lh "${DSH_SESSION_BACKUP}" || true

    echo "[SESSION] Extracting..."

    if tar \
        -xzf "${DSH_SESSION_BACKUP}" \
        -C "${DSH_LOCAL_SESSIONS}"
    then

        echo "[SESSION] Restore successful"

    else

        echo "[SESSION] WARNING: restore failed"
        echo "[SESSION] Starting with empty local sessions"

        rm -rf "${DSH_LOCAL_SESSIONS}"

        mkdir -p "${DSH_LOCAL_SESSIONS}"

    fi

else

    echo "[SESSION] No previous backup found"
    echo "[SESSION] Starting with empty sessions"

fi

echo
echo "[SESSION] Restored files:"

find "${DSH_LOCAL_SESSIONS}" \
    -maxdepth 3 \
    -type f \
    -print \
    2>/dev/null \
    | head -100 || true


# ==========================================================
# Session backup function
# ==========================================================

SESSION_BACKUP_RUNNING=0

backup_sessions() {

    # ------------------------------------------------------
    # Don't allow overlapping backups.
    # ------------------------------------------------------

    if [ "${SESSION_BACKUP_RUNNING}" -eq 1 ]; then
        return 0
    fi

    SESSION_BACKUP_RUNNING=1

    echo
    echo "[SESSION] ================================================"
    echo "[SESSION] Creating session backup"
    echo "[SESSION] ================================================"

    # ------------------------------------------------------
    # Nothing to backup.
    # ------------------------------------------------------

    if [ ! -d "${DSH_LOCAL_SESSIONS}" ]; then

        echo "[SESSION] Local session directory does not exist"

        SESSION_BACKUP_RUNNING=0

        return 0

    fi

    # ------------------------------------------------------
    # Check whether there is anything inside.
    # ------------------------------------------------------

    if ! find "${DSH_LOCAL_SESSIONS}" \
        -mindepth 1 \
        -print \
        -quit \
        | grep -q .
    then

        echo "[SESSION] No sessions yet"

        SESSION_BACKUP_RUNNING=0

        return 0

    fi

    # ------------------------------------------------------
    # Create archive LOCALLY first.
    #
    # This is important.
    #
    # tar operates on /tmp, where normal filesystem semantics
    # are available.
    # ------------------------------------------------------

    LOCAL_ARCHIVE="/tmp/dsh-session-backup-${RANDOM}-$$.tar.gz"

    rm -f "${LOCAL_ARCHIVE}"

    echo "[SESSION] Creating local archive..."

    if ! tar \
        -czf "${LOCAL_ARCHIVE}" \
        -C "${DSH_LOCAL_SESSIONS}" \
        .
    then

        echo "[SESSION] WARNING: tar failed"

        rm -f "${LOCAL_ARCHIVE}" || true

        SESSION_BACKUP_RUNNING=0

        return 0

    fi


    # ------------------------------------------------------
    # Verify archive.
    # ------------------------------------------------------

    if ! tar \
        -tzf "${LOCAL_ARCHIVE}" \
        >/dev/null 2>&1
    then

        echo "[SESSION] WARNING: generated archive is invalid"

        rm -f "${LOCAL_ARCHIVE}" || true

        SESSION_BACKUP_RUNNING=0

        return 0

    fi


    echo "[SESSION] Archive created:"
    ls -lh "${LOCAL_ARCHIVE}" || true


    # ------------------------------------------------------
    # Copy archive to HF bucket.
    #
    # IMPORTANT:
    #
    # We do NOT use:
    #
    #   ln
    #   cp -a
    #   rsync -H
    #
    # because we don't want hard-link semantics.
    #
    # This is simply one regular file copied to /data.
    # ------------------------------------------------------

    BACKUP_NEW="${DSH_SESSION_BACKUP}.new"

    rm -f "${BACKUP_NEW}" || true

    echo "[SESSION] Uploading to HF bucket..."

    if cp \
        "${LOCAL_ARCHIVE}" \
        "${BACKUP_NEW}"
    then

        # --------------------------------------------------
        # Replace previous backup.
        #
        # If rename works on the HF mount, use it.
        # --------------------------------------------------

        if mv \
            -f \
            "${BACKUP_NEW}" \
            "${DSH_SESSION_BACKUP}"
        then

            echo "[SESSION] Backup uploaded successfully"

        else

            echo "[SESSION] WARNING: could not replace backup"

            rm -f "${BACKUP_NEW}" || true

            rm -f "${LOCAL_ARCHIVE}" || true

            SESSION_BACKUP_RUNNING=0

            return 0

        fi

    else

        echo "[SESSION] WARNING: upload to HF bucket failed"

        rm -f "${BACKUP_NEW}" || true
        rm -f "${LOCAL_ARCHIVE}" || true

        SESSION_BACKUP_RUNNING=0

        return 0

    fi


    echo "[SESSION] Persistent backup:"
    ls -lh "${DSH_SESSION_BACKUP}" || true


    # ------------------------------------------------------
    # Remove local temporary archive.
    # ------------------------------------------------------

    rm -f "${LOCAL_ARCHIVE}" || true


    SESSION_BACKUP_RUNNING=0

}


# ==========================================================
# Background session backup
# ==========================================================

session_backup_loop() {

    echo "[SESSION] Background backup loop started"

    while true; do

        sleep "${DSH_SESSION_SYNC_INTERVAL}"

        backup_sessions || true

    done

}




    

# # ==========================================================
# # Refresh provider list on startup
# # ==========================================================

# echo
# echo "=========================================================="
# echo "[PROVIDERS] Refreshing provider list"
# echo "=========================================================="

# if [ -x "./free-model-rahul" ]; then

#     ./free-model-rahul --refresh --list || true

#     echo "[PROVIDERS] Refresh completed"

# else

#     echo "[PROVIDERS] WARNING: ./free-model-rahul not found"

# fi

# echo




echo
echo "=========================================================="
echo "[2/8] Fixing /data permissions"
echo "=========================================================="

chmod 755 /data 2>/dev/null || true

chmod 700 "${DSH_HOME}" 2>/dev/null || true

chmod 700 \
    "${DSH_HOME}/profiles" \
    "${DSH_HOME}/plugins" \
    "${DSH_HOME}/workspaces" \
    "${DSH_HOME}/cache" \
    "${DSH_HOME}/logs" \
    "${DSH_HOME}/tmp" \
    "${DSH_SESSION_BACKUP_DIR}" \
    "${DSH_LOCAL_SESSIONS}" \
    2>/dev/null || true


# ==========================================================
# 2b. Optional plugins
# ==========================================================

echo
echo "=========================================================="
echo "[2b/8] Installing optional plugins"
echo "=========================================================="

export PROBE_DISABLED=1

cd /app/deepseek-harness





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

    pnpm dsh plugin \
        --profile web \
        remove "${PLUGIN}" \
        >/tmp/plugin-remove.log 2>&1 || true

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

    if pnpm dsh plugin \
        --profile web \
        add "${PLUGIN}"
    then

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

pnpm approve-builds --all \
    >/tmp/plugin-approve.log 2>&1 || true





# ----------------------------------------------------------
# Install OhamLab Branding Plugin
# ----------------------------------------------------------

echo
echo "=========================================================="
echo "[OHAMLAB] Installing branding plugin"
echo "=========================================================="

export DSH_HOME=/data/dsh

OHAMLAB_BRAND_DIR="/app/ohamlab/plugins/harness-brand"

echo "[OHAMLAB] Checking plugin directory..."

if [ ! -f "${OHAMLAB_BRAND_DIR}/package.json" ]; then
    echo "[OHAMLAB] ERROR: package.json not found"
    echo "[OHAMLAB] Expected: ${OHAMLAB_BRAND_DIR}/package.json"

    echo "[OHAMLAB] Checking available plugin files:"
    ls -la /app/ohamlab/plugins/ 2>/dev/null || true

    exit 1
fi

cd /app/deepseek-harness

if pnpm dsh plugin \
    --profile web \
    add "${OHAMLAB_BRAND_DIR}"
then
    echo "[OHAMLAB] Branding plugin installed successfully"
else
    echo "[OHAMLAB] ERROR: Branding installation failed"
    exit 1
fi




# # ----------------------------------------------------------
# # OhamLab Search + Agent Lab eXCLUSIVE LOCAL 
# # ----------------------------------------------------------
# python -m pip install --break-system-packages \
#     ohamlab-agent \
#     ohamlab-agent-lab

# # Search verification
# which ohamlab
# ohamlab search "FastAPI documentation" --max-results 5

# # Agent Lab verification
# python -m pip show ohamlab-agent-lab

# # ----------------------------------------------------------
# # OhamLab Search + Agent Lab
# # ----------------------------------------------------------

# echo
# echo "[OHAMLAB] Installing OhamLab packages..."

# if python -m pip install --break-system-packages \
#     ohamlab-agent \
#     ohamlab-agent-lab
# then
#     echo "[OHAMLAB] Packages installed successfully"
# else
#     echo "[OHAMLAB] WARNING: Package installation failed"
# fi

# # ----------------------------------------------------------
# # Verify OhamLab Search
# # ----------------------------------------------------------

# echo
# echo "[OHAMLAB] Verifying Search..."

# if command -v ohamlab >/dev/null 2>&1; then
#     echo "[OHAMLAB] Search CLI: $(command -v ohamlab)"
# else
#     echo "[OHAMLAB] WARNING: Search CLI unavailable"
# fi

# # ----------------------------------------------------------
# # Verify OhamLab Agent Lab
# # ----------------------------------------------------------

# echo
# echo "[OHAMLAB] Verifying Agent Lab..."

# if python -m pip show ohamlab-agent-lab >/dev/null 2>&1; then
#     echo "[OHAMLAB] Agent Lab package installed"
# else
#     echo "[OHAMLAB] WARNING: Agent Lab package unavailable"
# fi







# ----------------------------------------------------------
# Install OhamLab Skills
# ----------------------------------------------------------


# ----------------------------------------------------------
# Install OhamLab Skills
# ----------------------------------------------------------


# ----------------------------------------------------------
# Install OhamLab Skills
# ----------------------------------------------------------


# ------------------------------------------------------------
# OHAMLAB — Verify Python runtime and integrations
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Checking Python runtime..."

OHAM_PYTHON="/opt/ohamlab-venv/bin/python"
OHAMLAB_ROOT="/app/deepseek-harness/ohamlab/vendor/ohamlab"

export PATH="/opt/ohamlab-venv/bin:${PATH}"

if [ ! -x "${OHAM_PYTHON}" ]; then
    echo "[OHAMLAB] ERROR: Python environment missing!"
    exit 1
fi

"${OHAM_PYTHON}" --version

if ! "${OHAM_PYTHON}" -m pip show ohamlab-agent >/dev/null 2>&1; then
    echo "[OHAMLAB] ERROR: Search package missing!"
    exit 1
fi

if ! "${OHAM_PYTHON}" -m pip show ohamlab-agent-lab >/dev/null 2>&1; then
    echo "[OHAMLAB] ERROR: Agent Lab package missing!"
    exit 1
fi

if ! command -v ohamlab >/dev/null 2>&1; then
    echo "[OHAMLAB] ERROR: Search CLI missing!"
    exit 1
fi

echo "[OHAMLAB] PASS: Python runtime ready"
echo "[OHAMLAB] PASS: OhamLab Search installed"
echo "[OHAMLAB] PASS: Agent Lab installed"
echo


# ============================================================
# OHAMLAB — Gateway, Local Integrations & Skills
# ============================================================

echo
echo "============================================================"
echo "[OHAMLAB] Initialising OhamLab integrations..."
echo "============================================================"

# ------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------

OHAMLAB_ROOT="/app/deepseek-harness/ohamlab/vendor/ohamlab"
OHAM_SKILLS_SOURCE="${OHAMLAB_ROOT}/skills"
OHAM_SKILLS_TARGET="/data/dsh/skills"
OHAM_REQUIREMENTS="${OHAMLAB_ROOT}/gateway/requirements.txt"

# Python interpreter used by the MCP gateway

# ------------------------------------------------------------
# Detect Python interpreter
# ------------------------------------------------------------

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

# Verify pip is available
if ! "${OHAM_PYTHON}" -m pip --version; then
    echo "[OHAMLAB] ERROR: pip is not installed for ${OHAM_PYTHON}"
    exit 1
fi


echo "[OHAMLAB] Root: ${OHAMLAB_ROOT}"
echo "[OHAMLAB] Python: ${OHAM_PYTHON}"
echo "[OHAMLAB] Skills source: ${OHAM_SKILLS_SOURCE}"
echo "[OHAMLAB] Skills target: ${OHAM_SKILLS_TARGET}"

# ------------------------------------------------------------
# 2. Verify OhamLab directories
# ------------------------------------------------------------

if [ ! -d "${OHAMLAB_ROOT}" ]; then
    echo "[OHAMLAB] ERROR: OhamLab directory not found!"
    echo "[OHAMLAB] Checking available directories..."

    ls -la /app/deepseek-harness/ohamlab/ 2>/dev/null || true
    ls -la /app/deepseek-harness/vendor/ 2>/dev/null || true
    ls -la /app/ohamlab/ 2>/dev/null || true

    exit 1
fi

if [ ! -d "${OHAM_SKILLS_SOURCE}" ]; then
    echo "[OHAMLAB] ERROR: Skills directory not found!"
    exit 1
fi

if [ ! -f "${OHAM_REQUIREMENTS}" ]; then
    echo "[OHAMLAB] ERROR: Gateway requirements.txt not found!"
    exit 1
fi

# ------------------------------------------------------------
# 3. Install OhamLab gateway dependencies
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Installing gateway dependencies..."

if ! "${OHAM_PYTHON}" -m pip install \
    -r "${OHAM_REQUIREMENTS}"; then

    echo "[OHAMLAB] ERROR: Gateway dependency installation failed!"
    exit 1
fi

echo "[OHAMLAB] PASS: Gateway dependencies installed"

# ------------------------------------------------------------
# 4. Install local Search and Agent Lab packages
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Installing local Search and Agent Lab..."

if ! "${OHAM_PYTHON}" -m pip install \
    "ohamlab-agent==0.1.2" \
    "ohamlab-agent-lab==7.0.0"; then

    echo "[OHAMLAB] ERROR: Local package installation failed!"
    exit 1
fi

echo "[OHAMLAB] PASS: Local packages installed"

# ------------------------------------------------------------
# 5. Verify local packages and CLI
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Verifying local installations..."

if ! "${OHAM_PYTHON}" -m pip show ohamlab-agent >/dev/null 2>&1; then
    echo "[OHAMLAB] ERROR: ohamlab-agent not installed!"
    exit 1
fi

if ! "${OHAM_PYTHON}" -m pip show ohamlab-agent-lab >/dev/null 2>&1; then
    echo "[OHAMLAB] ERROR: ohamlab-agent-lab not installed!"
    exit 1
fi

if ! command -v ohamlab >/dev/null 2>&1; then
    echo "[OHAMLAB] ERROR: OhamLab Search CLI not found on PATH!"
    exit 1
fi

echo "[OHAMLAB] PASS: Search CLI available"
echo "[OHAMLAB] PASS: Agent Lab package installed"

# ------------------------------------------------------------
# 6. Install OhamLab skills
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Installing OhamLab skills..."

mkdir -p "${OHAM_SKILLS_TARGET}"

for SKILL in web-search agent-lab research-workflow; do

    SOURCE="${OHAM_SKILLS_SOURCE}/${SKILL}"
    TARGET="${OHAM_SKILLS_TARGET}/${SKILL}"

    if [ ! -f "${SOURCE}/SKILL.md" ]; then
        echo "[OHAMLAB] ERROR: Missing ${SOURCE}/SKILL.md"
        exit 1
    fi

    mkdir -p "${TARGET}"

    # Copy the complete skill directory, including supporting files
    if ! cp -a "${SOURCE}/." "${TARGET}/"; then
        echo "[OHAMLAB] ERROR: Failed to install ${SKILL}"
        exit 1
    fi

    echo "[OHAMLAB] PASS: ${SKILL} installed"

done

# ------------------------------------------------------------
# 7. Verify installed skills
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Installed skills:"

find "${OHAM_SKILLS_TARGET}" -name SKILL.md -print

for SKILL in web-search agent-lab research-workflow; do

    if [ ! -f "${OHAM_SKILLS_TARGET}/${SKILL}/SKILL.md" ]; then
        echo "[OHAMLAB] ERROR: ${SKILL} verification failed!"
        exit 1
    fi

done

echo "[OHAMLAB] PASS: All OhamLab skills verified"

# ------------------------------------------------------------
# 8. Verify local adapters and gateway
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Checking MCP integration files..."

for FILE in \
    "${OHAMLAB_ROOT}/adapters/local_search_adapter.py" \
    "${OHAMLAB_ROOT}/adapters/local_agent_lab_adapter.py" \
    "${OHAMLAB_ROOT}/gateway/server.py"; do

    if [ ! -f "${FILE}" ]; then
        echo "[OHAMLAB] ERROR: Missing ${FILE}"
        exit 1
    fi

    echo "[OHAMLAB] PASS: $(basename "${FILE}")"

done

# ------------------------------------------------------------
# 9. Compile Python integration files
# ------------------------------------------------------------

echo
echo "[OHAMLAB] Validating Python integration files..."

if ! "${OHAM_PYTHON}" -m py_compile \
    "${OHAMLAB_ROOT}/adapters/local_search_adapter.py" \
    "${OHAMLAB_ROOT}/adapters/local_agent_lab_adapter.py" \
    "${OHAMLAB_ROOT}/gateway/server.py"; then

    echo "[OHAMLAB] ERROR: Python validation failed!"
    exit 1
fi

echo "[OHAMLAB] PASS: Python syntax validation successful"

# ------------------------------------------------------------
# 10. Complete
# ------------------------------------------------------------

echo
echo "============================================================"
echo "[OHAMLAB] Installation complete!"
echo "============================================================"
echo "[OHAMLAB] Search:        Installed"
echo "[OHAMLAB] Agent Lab:     Installed"
echo "[OHAMLAB] MCP Gateway:   Files verified"
echo "[OHAMLAB] Skills:        3 installed"
echo "[OHAMLAB] Skills path:   ${OHAM_SKILLS_TARGET}"
echo "============================================================"
echo


















# # ----------------------------------------------------------
# # Get planning-with-files skill
# # ----------------------------------------------------------

# echo
# echo "[SKILL] Preparing planning-with-files..."

# PLANNING_SKILL_DIR="/data/dsh/skills/planning-with-files"

# if [ -d "${PLANNING_SKILL_DIR}" ]; then

#     echo "[SKILL] planning-with-files already exists"

# else

#     echo "[SKILL] Cloning planning-with-files..."

#     mkdir -p /data/dsh/skills

#     if git clone \
#         https://github.com/OthmanAdi/planning-with-files.git \
#         "${PLANNING_SKILL_DIR}" \
#         >/tmp/planning-with-files-clone.log 2>&1
#     then

#         echo "[SKILL] OK: planning-with-files cloned"

#     else

#         echo "[SKILL] WARNING: failed to clone planning-with-files"
#         tail -20 /tmp/planning-with-files-clone.log 2>/dev/null || true

#     fi

# fi


# ----------------------------------------------------------
# Verify planning-with-files skill
# ----------------------------------------------------------

# echo
# echo "[SKILL] Verifying planning-with-files..."

# if [ -f "${PLANNING_SKILL_DIR}/SKILL.md" ]; then

#     echo "[SKILL] OK: planning-with-files ready"
#     echo "[SKILL] Location: ${PLANNING_SKILL_DIR}"

# else

#     echo "[SKILL] WARNING: SKILL.md not found"
#     echo "[SKILL] Expected: ${PLANNING_SKILL_DIR}/SKILL.md"

# fi

# # ----------------------------------------------------------
# # planning-with-files configuration
# # ----------------------------------------------------------

# echo
# echo "[PWF] Configuring planning-with-files..."

# export PWF_PLAN_ROOT="/data/dsh/planning-with-files/projects"

# mkdir -p "${PWF_PLAN_ROOT}"

# echo "[PWF] Plan root: ${PWF_PLAN_ROOT}"



# ==========================================================
# Refresh free LLM providers
# ==========================================================
# ==========================================================
# Refresh free LLM providers
# ==========================================================







echo
echo "=========================================================="
echo "[DSH] Installed web plugins"
echo "=========================================================="

pnpm dsh plugin \
    --profile web \
    list \
    2>&1 || true

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


# ==========================================================
# 4. Credential security + availability
# ==========================================================

echo
echo "=========================================================="
echo "[4/8] Securing credentials + checking providers"
echo "=========================================================="

if [ -f "${DSH_HOME}/.credentials.yaml" ]; then

    echo "[DSH] Fixing .credentials.yaml permissions"

    chmod 600 "${DSH_HOME}/.credentials.yaml"

    ls -l "${DSH_HOME}/.credentials.yaml"

fi


find "${DSH_HOME}" \
    -type f \
    \( \
        -name ".credentials.yaml" \
        -o -name "*credentials*.yaml" \
        -o -name "*credentials*.yml" \
    \) \
    -exec chmod 600 {} \; \
    2>/dev/null || true


check_env() {

    local NAME="$1"

    if [ -n "${!NAME:-}" ]; then
        echo "[PROVIDER] ${NAME}=configured"
    else
        echo "[PROVIDER] ${NAME}=NOT SET"
    fi

}


echo
echo "----------------------------------------------------------"
echo "[PROVIDER] Western"
echo "----------------------------------------------------------"

check_env GROQ_API_KEY
check_env CEREBRAS_API_KEY
check_env GEMINI_API_KEY
check_env MISTRAL_API_KEY
check_env SAMBANOVA_API_KEY
check_env COHERE_API_KEY


echo
echo "----------------------------------------------------------"
echo "[PROVIDER] Chinese - FIRST CLASS"
echo "----------------------------------------------------------"

check_env SILICONFLOW_API_KEY
check_env MODELSCOPE_API_KEY
check_env ZAI_API_KEY
check_env DASHSCOPE_API_KEY
check_env QIANFAN_API_KEY
check_env VOLCENGINE_API_KEY


echo
echo "----------------------------------------------------------"
echo "[PROVIDER] OpenRouter"
echo "----------------------------------------------------------"

check_env OPENROUTER_API_KEY


echo
echo "----------------------------------------------------------"
echo "[PROVIDER] Other"
echo "----------------------------------------------------------"

check_env HF_TOKEN
check_env NVIDIA_API_KEY
check_env AGNES_API_KEY
check_env LLAMA_API_KEY


# ==========================================================
# 5. Verify write access
# ==========================================================

echo
echo "=========================================================="
echo "[5/8] Testing persistent storage"
echo "=========================================================="

WRITE_TEST="${DSH_HOME}/.write-test"

if ! touch "${WRITE_TEST}"; then

    echo "[ERROR] Cannot write to ${DSH_HOME}"

    exit 1

fi

echo "DSH storage write test OK" > "${WRITE_TEST}"

if ! cat "${WRITE_TEST}" >/dev/null; then

    echo "[ERROR] Cannot read from ${DSH_HOME}"

    exit 1

fi

rm -f "${WRITE_TEST}"

echo "[DSH] /data write: OK"
echo "[DSH] /data read:  OK"


# ==========================================================
# 5b. Verify restored sessions
# ==========================================================

echo
echo "=========================================================="
echo "[SESSION] Restored session state"
echo "=========================================================="

SESSION_COUNT=$(
    find "${DSH_LOCAL_SESSIONS}" \
        -type f \
        2>/dev/null \
        | wc -l \
        | tr -d ' '
)

echo "[SESSION] Local session files: ${SESSION_COUNT}"

if [ "${SESSION_COUNT}" -gt 0 ]; then

    echo "[SESSION] Previous sessions restored"

else

    echo "[SESSION] No previous sessions restored"

fi


# ==========================================================
# 6. Show storage state
# ==========================================================

echo
echo "=========================================================="
echo "[6/8] Storage state"
echo "=========================================================="

echo "[DSH] DSH directory:"
ls -ld "${DSH_HOME}" || true

echo
echo "[DSH] Session directory:"
ls -ld "${DSH_HOME}/sessions" || true

echo
echo "[DSH] Session target:"
readlink -f "${DSH_HOME}/sessions" || true

echo
echo "[DSH] Backup:"
ls -lh "${DSH_SESSION_BACKUP}" 2>/dev/null || \
    echo "[SESSION] No backup archive"

echo
echo "[DSH] Files:"
ls -la "${DSH_HOME}" || true

echo
echo "[DSH] Disk:"
df -h /data || true

echo
echo "[DSH] Local session disk:"
df -h /tmp || true


# ==========================================================
# 7. Start DeepSeek Harness
# ==========================================================

echo
echo "=========================================================="
echo "[7/8] Starting DSH Web UI"
echo "=========================================================="

cd /app/deepseek-harness

DSH_LOG="/tmp/dsh.log"

rm -f "${DSH_LOG}"

echo "[DSH] Starting:"
echo "pnpm dsh web --host ${DSH_HOST} --port ${DSH_PORT} --trusted-host ${DSH_TRUSTED_HOST} --no-open"

pnpm dsh web \
    --host "${DSH_HOST}" \
    --port "${DSH_PORT}" \
    --trusted-host "${DSH_TRUSTED_HOST}" \
    --no-open \
    >"${DSH_LOG}" 2>&1 &

DSH_PID=$!

echo "[DSH] PID=${DSH_PID}"
echo "[DSH] Waiting for Web UI..."


DSH_READY=0


for i in $(seq 1 120); do

    if ! kill -0 "${DSH_PID}" 2>/dev/null; then

        echo
        echo "[DSH] ERROR: DSH exited during startup"
        echo
        echo "===== DSH LOG ====="

        cat "${DSH_LOG}" || true

        exit 1

    fi


    if curl -sf \
        "http://${DSH_HOST}:${DSH_PORT}/" \
        >/dev/null 2>&1
    then

        DSH_READY=1

        echo "[DSH] Web UI is ready"

        break

    fi


    if [ $((i % 10)) -eq 0 ]; then

        echo "[DSH] Still waiting... ${i}/120"

    fi


    sleep 1

done


if [ "${DSH_READY}" -ne 1 ]; then

    echo
    echo "[DSH] ERROR: Web UI did not become ready"
    echo
    echo "===== DSH LOG ====="

    cat "${DSH_LOG}" || true

    echo
    echo "===== LISTENING PORTS ====="

    ss -lntp || true

    exit 1

fi


# ==========================================================
# Start background session backup
#
# IMPORTANT:
# Start this AFTER DSH has successfully started.
# ==========================================================

echo
echo "=========================================================="
echo "[SESSION] Starting background persistence"
echo "=========================================================="

backup_sessions || true

session_backup_loop &

SESSION_BACKUP_PID=$!

echo "[SESSION] Backup PID: ${SESSION_BACKUP_PID}"
echo "[SESSION] Backup interval: ${DSH_SESSION_SYNC_INTERVAL}s"


# ==========================================================
# DSH diagnostics
# ==========================================================

echo
echo "=========================================================="
echo "[DSH] Process"
echo "=========================================================="

ps -ef | grep -E "node|dsh" | grep -v grep || true


echo
echo "=========================================================="
echo "[DSH] Listening ports"
echo "=========================================================="

ss -lntp || true


echo
echo "=========================================================="
echo "[DSH] Startup Log"
echo "=========================================================="

cat "${DSH_LOG}" || true


if ! kill -0 "${DSH_PID}" 2>/dev/null; then

    echo
    echo "[DSH] ERROR: DSH died after startup"

    exit 1

fi


# # ==========================================================
# # DSH UI BASIC AUTHENTICATION
# # ==========================================================

# echo "[AUTH] Configuring DSH login..."

# : "${DSH_USERNAME:?Missing DSH_USERNAME secret}"
# : "${DSH_PASSWORD:?Missing DSH_PASSWORD secret}"

# mkdir -p /data/dsh/auth

# HASH=$(openssl passwd -apr1 "$DSH_PASSWORD")

# printf '%s:%s\n' "$DSH_USERNAME" "$HASH" \
#     > /data/dsh/auth/.htpasswd

# chmod 600 /data/dsh/auth/.htpasswd

# echo "[AUTH] Login configured."

# ==========================================================
# 8. Start nginx
# ==========================================================

echo
echo "=========================================================="
echo "[8/8] Starting nginx :${PORT}"
echo "=========================================================="

nginx -t

nginx

echo "[NGINX] Started"
echo "[NGINX] Listening on :${PORT}"
echo "[NGINX] Proxying to ${DSH_HOST}:${DSH_PORT}"


# ==========================================================
# Graceful shutdown
# ==========================================================

shutdown() {

    echo
    echo "=========================================================="
    echo "[SHUTDOWN] Saving sessions before exit"
    echo "=========================================================="

    # ------------------------------------------------------
    # Kill backup loop first.
    # ------------------------------------------------------

    if [ -n "${SESSION_BACKUP_PID:-}" ]; then

        kill "${SESSION_BACKUP_PID}" 2>/dev/null || true

    fi


    # ------------------------------------------------------
    # Final session backup.
    # ------------------------------------------------------

    backup_sessions || true


    # ------------------------------------------------------
    # Stop DSH.
    # ------------------------------------------------------

    if [ -n "${DSH_PID:-}" ]; then

        kill "${DSH_PID}" 2>/dev/null || true

    fi


    echo "[SHUTDOWN] Complete"

}


trap shutdown EXIT
trap 'exit 0' SIGTERM SIGINT


# ==========================================================
# Monitor DSH
# ==========================================================

while true; do

    if ! kill -0 "${DSH_PID}" 2>/dev/null; then

        echo
        echo "=========================================================="
        echo "[DSH] PROCESS EXITED"
        echo "=========================================================="

        tail -300 "${DSH_LOG}" || true

        exit 1

    fi

    sleep 5

done
