Name:           ansible-periodic-service
Version:        1.0.0
Release:        1
Summary:        Systemd service for running Ansible playbooks periodically
License:        MIT
Group:          System Environment/Daemons
BuildArch:      noarch
Requires:       systemd
Requires:       ansible-core >= 2.12
Requires:       podman >= 4.0
Requires:       containers-common
Recommends:     ansible-collection-containers-podman

%description
A systemd service that runs Ansible playbooks periodically to manage containerized 
applications and system configuration. Features include:
- Task management with user repository scanning
- Podman quadlet management for system and user containers
- Vault integration for encrypted variables
- Template processing with Jinja2
- Automatic service startup and user lingering

%prep
# Copy source files to build directory
cp %{_sourcedir}/* .

%build
# No build needed for noarch package

%install
rm -rf %{buildroot}

# Create directories
mkdir -p %{buildroot}/usr/libexec/ansible-periodic
mkdir -p %{buildroot}/usr/lib/systemd/system
mkdir -p %{buildroot}/usr/share/ansible-periodic/playbooks
mkdir -p %{buildroot}/etc/ansible-periodic
mkdir -p %{buildroot}/var/lib/ansible-periodic
mkdir -p %{buildroot}/var/log/ansible-periodic

# Install systemd unit files
install -m 644 ansible-periodic@.service %{buildroot}/usr/lib/systemd/system/
install -m 644 ansible-periodic.service %{buildroot}/usr/lib/systemd/system/
install -m 644 ansible-periodic.timer %{buildroot}/usr/lib/systemd/system/
install -m 644 ansible-periodic-full.timer %{buildroot}/usr/lib/systemd/system/

# Install the script, configuration, and playbook
install -m 755 run-ansible-periodic.sh %{buildroot}/usr/libexec/ansible-periodic/
install -m 644 ansible-periodic.conf %{buildroot}/etc/ansible-periodic/
install -m 644 main.yml %{buildroot}/usr/share/ansible-periodic/playbooks/

# Install documentation
mkdir -p %{buildroot}/usr/share/doc/ansible-periodic-service
install -m 644 example-repo-structure.md %{buildroot}/usr/share/doc/ansible-periodic-service/

%files
%dir /usr/libexec/ansible-periodic
%dir /usr/share/ansible-periodic
%dir /usr/share/ansible-periodic/playbooks
%dir /etc/ansible-periodic
%dir /var/lib/ansible-periodic
%dir /var/log/ansible-periodic
/usr/libexec/ansible-periodic/run-ansible-periodic.sh
%config(noreplace) /etc/ansible-periodic/ansible-periodic.conf
/usr/share/ansible-periodic/playbooks/main.yml
/usr/share/doc/ansible-periodic-service/example-repo-structure.md
/usr/lib/systemd/system/ansible-periodic@.service
/usr/lib/systemd/system/ansible-periodic.service
/usr/lib/systemd/system/ansible-periodic.timer
/usr/lib/systemd/system/ansible-periodic-full.timer

%post
systemctl daemon-reload
systemctl enable ansible-periodic.timer
systemctl enable ansible-periodic-full.timer

%preun
if [ $1 = 0 ]; then
    systemctl stop ansible-periodic.timer
    systemctl stop ansible-periodic-full.timer
    systemctl disable ansible-periodic.timer
    systemctl disable ansible-periodic-full.timer
fi

%postun
if [ $1 = 0 ]; then
    systemctl daemon-reload
fi

%changelog
* Mon Jan 01 2024 Package Maintainer <maintainer@example.com> - 1.0.0-1
- Initial package 