#!/bin/bash

set -euo pipefail

# Default configuration (can be overridden by config file)
SCRIPT_DIR="/usr/libexec/ansible-periodic"
LOG_DIR="/var/log/ansible-periodic"
PLAYBOOK_DIR="/usr/share/ansible-periodic/playbooks"
INVENTORY_FILE="/etc/ansible-periodic/hosts"
ANSIBLE_HOST_KEY_CHECKING="False"
ANSIBLE_STDOUT_CALLBACK="yaml"
ANSIBLE_STDERR_CALLBACK="yaml"
MAIN_PLAYBOOK="main.yml"
USER_REPO_DIR="/var/ansible-repo"
CHANGES_EXTRA_VARS="run_mode=changes"
FULL_EXTRA_VARS="run_mode=full"
LOG_TIMESTAMP_FORMAT="+%Y%m%d-%H%M%S"
LOG_MESSAGE_FORMAT="+%Y-%m-%d %H:%M:%S"
CREATE_MISSING_PLAYBOOKS="true"
CREATE_MISSING_INVENTORY="true"

# Git repository defaults
GIT_REPO_URL=""
GIT_REPO_BRANCH="main"
GIT_USERNAME=""
GIT_PASSWORD=""
GIT_SSH_KEY=""
GIT_PULL_ENABLED="true"
GIT_CLEAN_ON_PULL="false"

# Source configuration file if it exists
CONFIG_FILE="/etc/ansible-periodic/ansible-periodic.conf"
if [ -f "${CONFIG_FILE}" ]; then
    # shellcheck source=/etc/ansible-periodic/ansible-periodic.conf
    source "${CONFIG_FILE}"
fi

# Get the mode from the systemd parameter
MODE="${1:-changes}"

# Setup logging
LOG_FILE="${LOG_DIR}/ansible-periodic-${MODE}-$(date ${LOG_TIMESTAMP_FORMAT}).log"
mkdir -p "${LOG_DIR}"

# Function to log messages
log() {
    echo "[$(date "${LOG_MESSAGE_FORMAT}")] $*" | tee -a "${LOG_FILE}"
}

# Setup file locking with stale lock detection
LOCK_FILE="/var/run/ansible-periodic-${MODE}.lock"
LOCK_PID_FILE="/var/run/ansible-periodic-${MODE}.pid"
LOCK_MAX_AGE_SECONDS=7200  # 2 hours - if lock is older than this, consider it stale

# Function to check if a process is running
is_process_running() {
    local pid=$1
    if [ -z "${pid}" ]; then
        return 1
    fi
    if kill -0 "${pid}" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to acquire lock with stale lock detection
acquire_lock() {
    # Try to acquire the lock non-blocking
    exec 200>"${LOCK_FILE}"
    if flock -n 200; then
        # Lock acquired, write our PID
        echo $$ > "${LOCK_PID_FILE}"
        return 0
    else
        # Lock is held, check if it's stale
        log "Lock file exists, checking if it's stale..."
        
        # Check if PID file exists and contains a valid PID
        if [ -f "${LOCK_PID_FILE}" ]; then
            local lock_pid=$(cat "${LOCK_PID_FILE}" 2>/dev/null)
            
            # Check if the process is still running
            if is_process_running "${lock_pid}"; then
                log "Another instance (PID ${lock_pid}) is already running in ${MODE} mode"
                return 1
            else
                log "Found stale lock from dead process (PID ${lock_pid}), removing..."
            fi
        else
            # No PID file, check lock file age
            if [ -f "${LOCK_FILE}" ]; then
                local lock_age=$(($(date +%s) - $(stat -c %Y "${LOCK_FILE}" 2>/dev/null || echo 0)))
                if [ ${lock_age} -gt ${LOCK_MAX_AGE_SECONDS} ]; then
                    log "Found stale lock file (${lock_age} seconds old), removing..."
                else
                    log "Lock file exists but no PID file found, and lock is recent (${lock_age}s old)"
                    return 1
                fi
            fi
        fi
        
        # Remove stale lock files
        rm -f "${LOCK_FILE}" "${LOCK_PID_FILE}" 2>/dev/null
        
        # Try to acquire lock again
        exec 200>"${LOCK_FILE}"
        if flock -n 200; then
            echo $$ > "${LOCK_PID_FILE}"
            log "Acquired lock after removing stale lock"
            return 0
        else
            log "Failed to acquire lock even after removing stale lock"
            return 1
        fi
    fi
}

# Function to release lock
release_lock() {
    rm -f "${LOCK_PID_FILE}" 2>/dev/null
    # flock will be automatically released when the file descriptor is closed (script exit)
}

# Set up trap to release lock on exit
trap release_lock EXIT INT TERM

# Acquire lock or exit
if ! acquire_lock; then
    exit 0
fi

log "Starting Ansible periodic run in '${MODE}' mode"

# Validate mode
case "${MODE}" in
    "changes"|"full")
        log "Running in ${MODE} mode"
        ;;
    *)
        log "ERROR: Unknown mode '${MODE}'. Valid modes are 'changes' or 'full'"
        exit 1
        ;;
esac

# Function to manage git repository
manage_git_repository() {
    if [ "${GIT_PULL_ENABLED}" != "true" ]; then
        log "Git pull is disabled, skipping repository management"
        return 0
    fi

    if [ -z "${GIT_REPO_URL}" ]; then
        log "No git repository URL configured, skipping git operations"
        return 0
    fi

    log "Managing git repository: ${GIT_REPO_URL}"

    # Check if git is available
    if ! command -v git &> /dev/null; then
        log "ERROR: git command not found"
        exit 1
    fi

    # Prepare git URL with authentication if needed
    local git_url="${GIT_REPO_URL}"
    if [ -n "${GIT_USERNAME}" ] && [ -n "${GIT_PASSWORD}" ]; then
        # Extract protocol and rest of URL
        local protocol=$(echo "${GIT_REPO_URL}" | sed -n 's/^\([^:]*\):\/\/.*/\1/p')
        local url_without_protocol=$(echo "${GIT_REPO_URL}" | sed 's/^[^:]*:\/\///')
        git_url="${protocol}://${GIT_USERNAME}:${GIT_PASSWORD}@${url_without_protocol}"
        log "Using authenticated git URL (credentials configured)"
    fi

    # Handle SSH key if provided
    if [ -n "${GIT_SSH_KEY}" ] && [ -f "${GIT_SSH_KEY}" ]; then
        export GIT_SSH_COMMAND="ssh -i ${GIT_SSH_KEY} -o StrictHostKeyChecking=no"
        log "Using SSH key: ${GIT_SSH_KEY}"
    fi

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "${USER_REPO_DIR}")"

    if [ -d "${USER_REPO_DIR}/.git" ]; then
        log "Repository exists, updating..."
        cd "${USER_REPO_DIR}"
        
        # Clean working directory if requested
        if [ "${GIT_CLEAN_ON_PULL}" = "true" ]; then
            log "Cleaning working directory..."
            git clean -fd
            git reset --hard HEAD
        fi
        
        # Fetch and pull latest changes
        #git fetch origin "${GIT_REPO_BRANCH}"
        local old_commit=$(git rev-parse HEAD)
        git checkout "${GIT_REPO_BRANCH}"
        git pull origin "${GIT_REPO_BRANCH}"
        local new_commit=$(git rev-parse HEAD)
        
        if [ "${old_commit}" != "${new_commit}" ]; then
            log "Repository updated: ${old_commit} -> ${new_commit}"
            # Set changed_dirs for changes mode
            if [ "${MODE}" = "changes" ]; then
                local changed_files=$(git diff --name-only "${old_commit}" "${new_commit}")
                
                # If any vars.yml changed, switch to full mode (affects all tasks)
                if echo "${changed_files}" | grep -q "vars\.yml$"; then
                    log "vars.yml changed - switching to full mode to ensure all tasks see updated variables"
                    MODE="full"
                    CHANGES_EXTRA_VARS="${FULL_EXTRA_VARS}"
                else
                    # Normal change detection
                    local changed_dirs=$(echo "${changed_files}" | xargs -I {} dirname {} | sort -u | tr '\n' ',' | sed 's/,$//')
                    if [ -n "${changed_dirs}" ]; then
                        log "Changed directories: ${changed_dirs}"
                        CHANGES_EXTRA_VARS="${CHANGES_EXTRA_VARS} changed_dirs=${changed_dirs}"
                    fi
                fi
            fi
        else
            log "Repository already up to date"
        fi
    else
        log "Repository doesn't exist, cloning..."
        rm -rf "${USER_REPO_DIR}"
        git clone --branch "${GIT_REPO_BRANCH}" "${git_url}" "${USER_REPO_DIR}"
        log "Repository cloned successfully"
    fi

    # Verify repository structure
    if [ ! -d "${USER_REPO_DIR}" ]; then
        log "ERROR: Repository directory ${USER_REPO_DIR} not found after git operations"
        exit 1
    fi

    log "Git repository management completed successfully"
}

# Check if Ansible is available
if ! command -v ansible-playbook &> /dev/null; then
    log "ERROR: ansible-playbook command not found"
    exit 1
fi

# Manage git repository before running ansible
manage_git_repository

# In changes mode, exit early if no changes were detected
if [ "${MODE}" = "changes" ]; then
    # Check if changed_dirs was set (indicates changes were detected)
    if [[ "${CHANGES_EXTRA_VARS}" != *"changed_dirs="* ]]; then
        log "No changes detected in changes mode, exiting without running playbook"
        exit 0
    fi
fi

# Set Ansible configuration from config
export ANSIBLE_HOST_KEY_CHECKING="${ANSIBLE_HOST_KEY_CHECKING}"
export ANSIBLE_STDOUT_CALLBACK="${ANSIBLE_STDOUT_CALLBACK}"
export ANSIBLE_STDERR_CALLBACK="${ANSIBLE_STDERR_CALLBACK}"

# Set vault password file if it exists
VAULT_PASSWORD_FILE="/var/lib/ansible-periodic/.vault_password"
if [ -f "${VAULT_PASSWORD_FILE}" ]; then
    export ANSIBLE_VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE}"
    log "Using vault password file: ${VAULT_PASSWORD_FILE}"
fi

# Set the main playbook path
PLAYBOOK="${PLAYBOOK_DIR}/${MAIN_PLAYBOOK}"

# Determine extra variables based on mode
if [ "${MODE}" = "changes" ]; then
    EXTRA_VARS="${CHANGES_EXTRA_VARS} user_repo_dir=${USER_REPO_DIR}"
else
    EXTRA_VARS="${FULL_EXTRA_VARS} user_repo_dir=${USER_REPO_DIR}"
fi

# Check if playbook exists
if [ ! -f "${PLAYBOOK}" ] && [ "${CREATE_MISSING_PLAYBOOKS}" = "true" ]; then
    log "WARNING: Playbook ${PLAYBOOK} not found. Creating a placeholder."
    mkdir -p "${PLAYBOOK_DIR}"
    cat > "${PLAYBOOK}" << EOF
---
- name: Ansible Periodic Placeholder Run
  hosts: localhost
  connection: local
  gather_facts: yes
  vars:
    user_repo_dir: "${USER_REPO_DIR}"
    run_mode: "{{ run_mode | default('full') }}"
    changed_dirs: ""
  
  tasks:
    - name: Log the periodic run
      debug:
        msg: "Running Ansible periodic task in {{ run_mode }} mode at {{ ansible_date_time.iso8601 }}"
    
    - name: Check if user repository exists
      stat:
        path: "{{ user_repo_dir }}"
      register: user_repo_stat
    
    - name: Create placeholder user repository if missing
      file:
        path: "{{ user_repo_dir }}"
        state: directory
        mode: '0755'
      when: not user_repo_stat.stat.exists
    
    - name: Create log entry
      lineinfile:
        path: "${LOG_DIR}/ansible-runs.log"
        line: "{{ ansible_date_time.iso8601 }}: {{ run_mode }} run completed successfully (placeholder mode)"
        create: yes
        mode: '0644'
    
    - name: Show completion message
      debug:
        msg: "Placeholder run completed. Place your actual main.yml playbook in ${PLAYBOOK_DIR}/ and configure your user repository at {{ user_repo_dir }}"
EOF
fi

# Check if inventory exists
if [ ! -f "${INVENTORY_FILE}" ] && [ "${CREATE_MISSING_INVENTORY}" = "true" ]; then
    log "WARNING: Inventory ${INVENTORY_FILE} not found. Creating a placeholder."
    mkdir -p "$(dirname "${INVENTORY_FILE}")"
    cat > "${INVENTORY_FILE}" << EOF
[local]
localhost ansible_connection=local
EOF
fi

# Run the Ansible playbook
log "Executing: ansible-playbook -i ${INVENTORY_FILE} ${PLAYBOOK} --extra-vars '${EXTRA_VARS}'"

if ansible-playbook \
    -i "${INVENTORY_FILE}" \
    "${PLAYBOOK}" \
    --extra-vars "${EXTRA_VARS}" \
    2>&1 | tee -a "${LOG_FILE}"; then
    
    log "Ansible periodic run completed successfully in ${MODE} mode"
    exit 0
else
    exit_code=${PIPESTATUS[0]}
    log "ERROR: Ansible periodic run failed in ${MODE} mode (exit code: ${exit_code})"
    exit ${exit_code}
fi 