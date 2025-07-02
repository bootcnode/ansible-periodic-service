#!/bin/bash

set -euo pipefail

# Default configuration (can be overridden by config file)
SCRIPT_DIR="/usr/libexec/ansible-periodic"
LOG_DIR="/var/log/ansible-periodic"
PLAYBOOK_DIR="/usr/share/ansible-periodic/playbooks"
INVENTORY_FILE="/etc/ansible-periodic/hosts"
ANSIBLE_HOST_KEY_CHECKING="False"
ANSIBLE_STDOUT_CALLBACK="oneline"
ANSIBLE_STDERR_CALLBACK="oneline"
MAIN_PLAYBOOK="main.yml"
USER_REPO_DIR="/var/ansible-repo"
CHANGES_EXTRA_VARS="run_mode=changes"
FULL_EXTRA_VARS="run_mode=full"
LOG_TIMESTAMP_FORMAT="+%Y%m%d-%H%M%S"
LOG_MESSAGE_FORMAT="+%Y-%m-%d %H:%M:%S"
CREATE_MISSING_PLAYBOOKS="true"
CREATE_MISSING_INVENTORY="true"

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

# Check if Ansible is available
if ! command -v ansible-playbook &> /dev/null; then
    log "ERROR: ansible-playbook command not found"
    exit 1
fi

# Set Ansible configuration from config
export ANSIBLE_HOST_KEY_CHECKING="${ANSIBLE_HOST_KEY_CHECKING}"
export ANSIBLE_STDOUT_CALLBACK="${ANSIBLE_STDOUT_CALLBACK}"
export ANSIBLE_STDERR_CALLBACK="${ANSIBLE_STDERR_CALLBACK}"

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
    >> "${LOG_FILE}" 2>&1; then
    
    log "Ansible periodic run completed successfully in ${MODE} mode"
    exit 0
else
    exit_code=$?
    log "ERROR: Ansible periodic run failed in ${MODE} mode (exit code: ${exit_code})"
    exit ${exit_code}
fi 