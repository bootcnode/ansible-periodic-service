# Example User Repository Structure

This file shows how to organize your user repository (default: `/var/ansible-repo/`) for the ansible-periodic-service.

## Directory Structure

```
/var/ansible-repo/
├── webapp/
│   ├── task.yml                      # Application-specific tasks
│   └── system-quadlets/
│       ├── webapp.container          # Podman container definition
│       ├── webapp-db.container       # Database container
│       └── vault.yml                 # Encrypted variables
├── monitoring/
│   ├── task.yml
│   └── system-quadlets/
│       ├── prometheus.container.j2   # Template with variables
│       └── grafana.container
├── user-services/
│   └── user-quadlets/
│       ├── alice/
│       │   ├── personal-app.container
│       │   └── vault.yml
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

### vault.yml (Encrypted Variables)
```yaml
---
# Encrypt with: ansible-vault encrypt vault.yml
database_url: "postgresql://webapp:secret123@localhost/webapp"
webapp_image: "registry.example.com/webapp:v1.2.3"
webapp_port: "8443"
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
4. **Vault security**: Always encrypt sensitive data in `vault.yml` files
5. **Testing**: Test quadlets manually before adding to repository
6. **Dependencies**: Use `After=` and `Requires=` in quadlet files appropriately 