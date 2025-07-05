# Ansible Periodic Service

A systemd-based service that runs Ansible playbooks periodically to manage containerized applications and system configuration in two modes:

- **Changes mode**: Runs every 15 minutes for quick updates to specific changed directories
- **Full mode**: Runs every 24 hours at 3 AM for complete system configuration

**Key Features:**
- **Task Management**: Finds and executes `task.yml` files from user repositories
- **Podman Quadlets**: Manages system and user container services via Podman quadlets
- **Variable Integration**: Loads variables from `vars.yml` files with hierarchical support
- **Template Processing**: Supports Jinja2 templates for dynamic configuration
- **User Services**: Manages per-user container services with proper ownership
- **Service Auto-start**: Automatically starts and enables container services

## Features

- **Dual operational modes** for different update frequencies
- **Systemd timer integration** for reliable scheduling
- **Comprehensive logging** with timestamped log files
- **Self-healing** playbook and inventory creation
- **RPM packaging** for easy deployment on RHEL/CentOS/Fedora

## Installation

### From RPM Package

1. Build the RPM:
   ```bash
   make rpm
   ```

2. Install the package:
   ```bash
   sudo dnf install rpmbuild/RPMS/noarch/ansible-periodic-service-*.rpm
   ```

3. Enable and start the timers:
   ```bash
   sudo systemctl enable --now ansible-periodic.timer
   sudo systemctl enable --now ansible-periodic-full.timer
   ```

### Manual Installation

If you prefer manual installation, copy the systemd unit files to `/usr/lib/systemd/system/` and the script to `/opt/ansible-periodic-service/scripts/`.

## Usage

### Automatic Operation

Once installed and enabled, the service runs automatically:

- **Changes mode**: Every 15 minutes (with 3-minute randomized delay)
- **Full mode**: Daily at 3 AM (with 2-hour randomized delay)

### Manual Execution

Run specific modes manually:

```bash
# Run changes mode
sudo systemctl start ansible-periodic@changes.service

# Run full mode
sudo systemctl start ansible-periodic@full.service
```

### Monitoring

Check service status:
```bash
sudo systemctl status ansible-periodic.timer
sudo systemctl status ansible-periodic-full.timer
```

View logs:
```bash
# Systemd journal
sudo journalctl -u ansible-periodic@changes.service
sudo journalctl -u ansible-periodic@full.service

# Application logs
sudo tail -f /var/log/ansible-periodic/ansible-periodic-*.log
```

## Configuration

### Directory Structure

- `/usr/libexec/ansible-periodic/` - Main execution script
- `/usr/share/ansible-periodic/playbooks/` - Main playbook (`main.yml`)
- `/etc/ansible-periodic/` - Configuration files and inventory
  - `ansible-periodic.conf` - Main configuration file
  - `hosts` - Ansible inventory (auto-created)
- `/var/lib/ansible-periodic/` - Runtime data
- `/var/log/ansible-periodic/` - Log files

### Customization

1. **Edit configuration** at `/etc/ansible-periodic/ansible-periodic.conf`:
   - Modify paths, playbook names, and Ansible settings
   - Enable/disable auto-creation of missing files

2. **Set up your user repository** at `/var/ansible-repo/` (configurable):
   - Create `task.yml` files in subdirectories for application tasks
   - Add `system-quadlets/` directories with Podman container configs
   - Add `user-quadlets/USERNAME/` directories for user-specific containers
   - Include `vars.yml` files for variables (global and per-directory)
   - Use `.j2` templates for dynamic configuration

3. **Modify inventory** at `/etc/ansible-periodic/hosts`

4. **Create user repository structure**:
   ```
   /var/ansible-repo/
   ├── app1/
   │   ├── task.yml
   │   └── system-quadlets/
   │       ├── myapp.container
   │       └── vars.yml
   ├── app2/
   │   ├── task.yml
   │   └── user-quadlets/
   │       └── username/
   │           └── userapp.container.j2
   └── finally/
       └── finally.yml
   ```

5. **Adjust schedules** using systemd override files (see Customizing Schedules below)

## Customizing Schedules

Instead of editing the package-installed timer files directly, use systemd override files to customize schedules. This ensures your changes persist through package upgrades.

### Method 1: Using `systemctl edit` (Recommended)

```bash
# Customize the changes timer (runs every 15 minutes by default)
sudo systemctl edit ansible-periodic.timer

# Customize the full timer (runs daily at 3 AM by default)  
sudo systemctl edit ansible-periodic-full.timer
```

This opens an editor where you can add override settings:

```ini
[Timer]
# Change changes mode to run every 5 minutes instead of 15
OnUnitActiveSec=5min
OnBootSec=2min

# Reduce randomized delay
RandomizedDelaySec=1min
```

### Method 2: Manual Override Files

Create override directories and files manually:

```bash
# Create override directory for changes timer
sudo mkdir -p /etc/systemd/system/ansible-periodic.timer.d

# Create override configuration
sudo tee /etc/systemd/system/ansible-periodic.timer.d/schedule.conf << EOF
[Timer]
# Run every 10 minutes instead of 15
OnUnitActiveSec=10min
OnBootSec=3min
RandomizedDelaySec=2min
EOF

# Create override for full timer  
sudo mkdir -p /etc/systemd/system/ansible-periodic-full.timer.d

sudo tee /etc/systemd/system/ansible-periodic-full.timer.d/schedule.conf << EOF
[Timer]
# Run at 2 AM instead of 3 AM
OnCalendar=*-*-* 02:00:00
# Start 15 minutes after boot instead of 30
OnBootSec=15min
# Reduce randomized delay to 1 hour
RandomizedDelaySec=1h
EOF
```

### Apply Changes

After creating override files, reload systemd and restart timers:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ansible-periodic.timer
sudo systemctl restart ansible-periodic-full.timer
```

### View Effective Configuration

Check what settings are actually being used:

```bash
# Show effective timer configuration
systemctl cat ansible-periodic.timer
systemctl cat ansible-periodic-full.timer

# Show timer status and next run times
systemctl list-timers ansible-periodic*
```

### Common Schedule Examples

**More Frequent Changes Mode:**
```ini
[Timer]
OnUnitActiveSec=5min
OnBootSec=1min
RandomizedDelaySec=30s
```

**Different Daily Time:**
```ini
[Timer]
OnCalendar=*-*-* 01:30:00
OnBootSec=20min
RandomizedDelaySec=30min
```

**Weekly Full Runs:**
```ini
[Timer]
OnCalendar=Sun *-*-* 03:00:00
OnBootSec=30min
RandomizedDelaySec=2h
```

**Disable a Timer:**
```ini
[Timer]
OnCalendar=
OnUnitActiveSec=
OnBootSec=
```

### Remove Overrides

To remove customizations and return to package defaults:

```bash
# Remove specific override files
sudo rm -rf /etc/systemd/system/ansible-periodic.timer.d
sudo rm -rf /etc/systemd/system/ansible-periodic-full.timer.d

# Or use systemctl revert
sudo systemctl revert ansible-periodic.timer
sudo systemctl revert ansible-periodic-full.timer

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ansible-periodic.timer
sudo systemctl restart ansible-periodic-full.timer
```

## Development

### Building from Source

```bash
# Install build dependencies
sudo dnf install rpm-build rpmlint

# Build RPM
make rpm

# Clean build artifacts
make clean
```

### File Structure

- `ansible-periodic-service.spec` - RPM specification
- `ansible-periodic@.service` - Parameterized systemd service
- `ansible-periodic.timer` - Timer for changes mode
- `ansible-periodic-full.timer` - Timer for full mode  
- `run-ansible-periodic.sh` - Main execution script
- `Makefile` - Build automation

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the RPM build and installation
5. Submit a pull request
