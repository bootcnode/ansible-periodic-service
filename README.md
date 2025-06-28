# Ansible Periodic Service

A systemd-based service that runs Ansible playbooks periodically to manage containerized applications and system configuration in two modes:

- **Changes mode**: Runs every 15 minutes for quick updates to specific changed directories
- **Full mode**: Runs every 24 hours at 3 AM for complete system configuration

**Key Features:**
- **Task Management**: Finds and executes `task.yml` files from user repositories
- **Podman Quadlets**: Manages system and user container services via Podman quadlets
- **Vault Integration**: Loads encrypted variables from `vault.yml` files
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
   - Include `vault.yml` files for encrypted variables
   - Use `.j2` templates for dynamic configuration

3. **Modify inventory** at `/etc/ansible-periodic/hosts`

4. **Create user repository structure**:
   ```
   /var/ansible-repo/
   ├── app1/
   │   ├── task.yml
   │   └── system-quadlets/
   │       ├── myapp.container
   │       └── vault.yml
   ├── app2/
   │   ├── task.yml
   │   └── user-quadlets/
   │       └── username/
   │           └── userapp.container.j2
   └── finally/
       └── finally.yml
   ```

5. **Adjust schedules** by editing timer files in `/usr/lib/systemd/system/`

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
