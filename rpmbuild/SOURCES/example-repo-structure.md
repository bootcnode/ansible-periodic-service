# Example User Repository Structure

This file shows how to organize your user repository (default: `/var/ansible-repo/`) for the ansible-periodic-service.

## Directory Structure

```
/var/ansible-repo/
├── handlers.yml                       # Global handlers (optional)
├── vars.yml                          # Global variables (optional)
├── webapp/
│   ├── task.yml                      # Application-specific tasks
│   └── system-quadlets/
│       ├── webapp.container          # Podman container definition
│       ├── webapp-db.container       # Database container
│       └── vars.yml                  # Variables for templates
├── monitoring/
│   ├── task.yml
│   └── system-quadlets/
│       ├── prometheus.container.j2   # Template with variables
│       └── grafana.container
├── user-services/
│   └── user-quadlets/
│       ├── alice/
│       │   ├── personal-app.container
│       │   └── vars.yml
│       └── bob/
│           └── dev-env.container.j2
└── finally/
    └── finally.yml                   # Cleanup/final tasks
```

## File Examples

### task.yml (Application Tasks)
```yaml
---
- name: Ensure application directory exists
  file:
    path: /opt/webapp
    state: directory
    mode: '0755'

- name: Configure application
  template:
    src: app.conf.j2
    dest: /opt/webapp/app.conf
    mode: '0644'

- name: Use variables from vars.yml in tasks
  command: echo "Database URL: {{ env_vars.database_url }}"
  # Variables loaded from vars.yml files are available via env_vars dictionary
  # Use env_vars.variable_name to access them in task.yml files
```

### system-quadlets/webapp.container (Podman Quadlet)
```ini
[Unit]
Description=Web Application
After=webapp-db.service
Requires=webapp-db.service

[Container]
Image=docker.io/nginx:alpine
PublishPort=8080:80
Volume=/opt/webapp:/usr/share/nginx/html:ro
Environment=DATABASE_URL=postgresql://webapp:password@localhost/webapp

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
```

### system-quadlets/webapp.container.j2 (Template)
```ini
[Unit]
Description=Web Application
After=webapp-db.service
Requires=webapp-db.service

[Container]
Image={{ webapp_image | default('docker.io/nginx:alpine') }}
PublishPort={{ webapp_port | default('8080') }}:80
Volume=/opt/webapp:/usr/share/nginx/html:ro
Environment=DATABASE_URL={{ database_url }}

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
```

### vars.yml (Variables)
```yaml
---
# Variables for templates (can be encrypted with ansible-vault if needed)
database_url: "postgresql://webapp:secret123@localhost/webapp"
webapp_image: "registry.example.com/webapp:v1.2.3"
webapp_port: "8443"
```

**Using Variables:**

Variables from `vars.yml` files are available in two contexts:

1. **In task.yml files**: Access via `env_vars.variable_name`
   ```yaml
   - name: Use variable in task
     command: echo "{{ env_vars.database_url }}"
     loop: "{{ env_vars.zerotier_networks }}"
   ```

2. **In .j2 template files**: Access directly as `variable_name` or via `env_vars.variable_name`
   ```ini
   # Both work in templates:
   DatabaseURL={{ database_url }}
   DatabaseURL={{ env_vars.database_url }}
   ```

### handlers.yml (Global Handlers)

Place a `handlers.yml` file in the repository root to define handlers that can be notified from any `task.yml` file:

```yaml
---
# Global handlers available to all task.yml files
- name: restart gdm
  systemd:
    name: gdm
    state: restarted

- name: restart nginx
  systemd:
    name: nginx
    state: restarted

- name: reload systemd
  systemd:
    daemon_reload: yes
```

**Using Handlers:**

In your `task.yml` files, you can notify handlers defined in `handlers.yml`:

```yaml
---
- name: Update configuration
  template:
    src: config.j2
    dest: /etc/app/config
  notify: restart nginx

- name: Update GDM configuration
  copy:
    src: gdm.conf
    dest: /etc/gdm/custom.conf
  notify: restart gdm
```

**Important Notes:**
- Handlers are executed at the end of the playbook run (or when `meta: flush_handlers` is used)
- Handlers only run if the notifying task reports `changed: true`
- Handlers must be defined in the root `handlers.yml` file (not in individual task.yml files)
- The `handlers.yml` file is optional - if it doesn't exist, it will be ignored

## Variable Hierarchy

The ansible-periodic-service supports a hierarchical variable system using `vars.yml` files:

### Global Variables
Place a `vars.yml` file in the repository root for variables available to all tasks and templates:

```
/var/ansible-repo/
├── vars.yml                          # Global variables
├── webapp/
│   ├── task.yml
│   └── vars.yml                      # Overrides global vars
└── monitoring/
    ├── task.yml
    └── system-quadlets/
        └── vars.yml                  # Overrides global + webapp vars
```

### Loading Order
1. **Global vars.yml** (repository root) - loaded first
2. **Directory-specific vars.yml** - loaded second, overrides global
3. **Quadlet-specific vars.yml** - loaded last, overrides all previous

### Example Global vars.yml
```yaml
---
# Common settings for all applications
registry_url: "registry.example.com"
environment: "production"
log_level: "info"
admin_email: "admin@example.com"
```

### Example Directory vars.yml
```yaml
---
# Webapp-specific overrides
environment: "staging"  # Overrides global
webapp_port: "8443"     # New variable
```

### finally/finally.yml (Cleanup Tasks)
```yaml
---
- name: Clean up temporary files
  file:
    path: /tmp/ansible-periodic-*
    state: absent

- name: Send completion notification
  debug:
    msg: "Ansible periodic run completed at {{ ansible_date_time.iso8601 }}"
```

## Operation Modes

### Full Mode
- Processes all directories and files
- Runs all `task.yml` files found
- Processes all quadlet directories
- Suitable for complete system configuration

### Changes Mode
- Only processes specified changed directories
- Pass `changed_dirs` parameter with comma-separated directory names
- Example: `changed_dirs=webapp,monitoring`
- Ideal for targeted updates based on git changes

## User Quadlets

User quadlets are container services that run under specific user accounts:

1. **Directory structure**: `user-quadlets/USERNAME/`
2. **File ownership**: Automatically set to the specified user
3. **Service scope**: Runs as user services (`systemctl --user`)
4. **Lingering**: Automatically enabled for users with quadlets
5. **Home directory**: Uses `/var/home/USERNAME/.config/containers/systemd/`

## Best Practices

1. **Modular organization**: One directory per application/service
2. **Consistent naming**: Use descriptive names for containers and services
3. **Template usage**: Use `.j2` templates for dynamic configuration
4. **Variable security**: Encrypt sensitive data in `vars.yml` files using ansible-vault when needed
5. **Testing**: Test quadlets manually before adding to repository
6. **Dependencies**: Use `After=` and `Requires=` in quadlet files appropriately 