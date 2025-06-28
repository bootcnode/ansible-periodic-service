# Building the Ansible Periodic Service RPM

This project creates an RPM package for a systemd service that runs Ansible playbooks periodically.

## Prerequisites

- RHEL/CentOS/Fedora system with RPM development tools
- Install required packages:
  ```bash
  sudo dnf install rpm-build rpmlint
  ```

## Quick Build

1. **Build the RPM:**
   ```bash
   make rpm
   ```

2. **Install the RPM:**
   ```bash
   make install
   ```

3. **Or do both in one step:**
   ```bash
   make test-install
   ```

## Manual Build Process

If you prefer to build manually:

1. **Prepare build environment:**
   ```bash
   make prepare
   ```

2. **Build source RPM:**
   ```bash
   make srpm
   ```

3. **Build binary RPM:**
   ```bash
   rpmbuild --define "_topdir $(pwd)/rpmbuild" --rebuild rpmbuild/SRPMS/ansible-periodic-service-1.0.0-1.*.src.rpm
   ```

## Service Architecture

The package installs:

- **ansible-periodic@.service**: Parameterized service template
- **ansible-periodic.timer**: Runs "changes" mode every 15 minutes
- **ansible-periodic-full.timer**: Runs "full" mode every 24 hours at 3 AM
- **run-ansible-periodic.sh**: Main script that executes Ansible playbooks

## Usage After Installation

1. **Enable the timers:**
   ```bash
   sudo systemctl enable ansible-periodic.timer
   sudo systemctl enable ansible-periodic-full.timer
   sudo systemctl start ansible-periodic.timer
   sudo systemctl start ansible-periodic-full.timer
   ```

2. **Manual execution:**
   ```bash
   # Run changes mode manually
   sudo systemctl start ansible-periodic@changes.service
   
   # Run full mode manually
   sudo systemctl start ansible-periodic@full.service
   ```

3. **Check status:**
   ```bash
   sudo systemctl status ansible-periodic.timer
   sudo systemctl status ansible-periodic-full.timer
   ```

4. **View logs:**
   ```bash
   sudo journalctl -u ansible-periodic@changes.service
   sudo journalctl -u ansible-periodic@full.service
   sudo tail -f /var/log/ansible-periodic/ansible-periodic-*.log
   ```

## File Locations

- **Scripts**: `/usr/libexec/ansible-periodic/`
- **Playbooks**: `/usr/share/ansible-periodic/playbooks/` - Contains main.yml
- **Configuration**: `/etc/ansible-periodic/`
  - `ansible-periodic.conf` - Main configuration file
  - `hosts` - Ansible inventory (created on first run)
- **Runtime data**: `/var/lib/ansible-periodic/`
- **Logs**: `/var/log/ansible-periodic/`
- **Systemd units**: `/usr/lib/systemd/system/`

## Customization

After installation, you can:

1. **Edit the configuration** at `/etc/ansible-periodic/ansible-periodic.conf`
2. **Configure your user repository** at `/var/ansible-repo/` with your applications and quadlets
3. **Modify the inventory** at `/etc/ansible-periodic/hosts`
4. **Adjust timer schedules** by editing the systemd timer files and running `systemctl daemon-reload`

## Cleanup

To remove build artifacts:
```bash
make clean
```

To uninstall the package:
```bash
sudo dnf remove ansible-periodic-service
``` 