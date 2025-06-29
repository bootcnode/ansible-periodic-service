PACKAGE_NAME = ansible-periodic-service
VERSION = 1.0.0
RELEASE = 1
ARCH = noarch

# RPM build directories
TOPDIR = $(shell pwd)/rpmbuild
SOURCEDIR = $(TOPDIR)/SOURCES
SPECDIR = $(TOPDIR)/SPECS
RPMDIR = $(TOPDIR)/RPMS
SRPMDIR = $(TOPDIR)/SRPMS
BUILDDIR = $(TOPDIR)/BUILD

# Source files
SYSTEMD_FILES = ansible-periodic@.service ansible-periodic.service ansible-periodic.timer ansible-periodic-full.timer
SCRIPT_FILES = run-ansible-periodic.sh
CONFIG_FILES = ansible-periodic.conf
PLAYBOOK_FILES = main.yml
DOC_FILES = example-repo-structure.md
SPEC_FILE = $(PACKAGE_NAME).spec

# DEB build directories
DEBDIR = $(shell pwd)/debbuild
DEBIAN_PKG_DIR = $(DEBDIR)/$(PACKAGE_NAME)_$(VERSION)-$(RELEASE)

.PHONY: all clean rpm srpm prepare install deb

all: rpm deb

# Create RPM build directory structure
prepare:
	@echo "Creating RPM build directories..."
	mkdir -p $(SOURCEDIR) $(SPECDIR) $(RPMDIR) $(SRPMDIR) $(BUILDDIR)
	cp $(SPEC_FILE) $(SPECDIR)/
	cp $(SYSTEMD_FILES) $(SCRIPT_FILES) $(CONFIG_FILES) $(PLAYBOOK_FILES) $(DOC_FILES) $(SOURCEDIR)/

# Build source RPM
srpm: prepare
	@echo "Building source RPM..."
	rpmbuild --define "_topdir $(TOPDIR)" -bs $(SPECDIR)/$(SPEC_FILE)

# Build binary RPM
rpm: srpm
	@echo "Building binary RPM..."
	rpmbuild --define "_topdir $(TOPDIR)" --rebuild $(SRPMDIR)/$(PACKAGE_NAME)-$(VERSION)-$(RELEASE).src.rpm

# Install the built RPM (requires sudo)
install: rpm
	@echo "Installing RPM..."
	sudo dnf install -y $(RPMDIR)/$(ARCH)/$(PACKAGE_NAME)-$(VERSION)-$(RELEASE).$(ARCH).rpm

# Install the built DEB (requires sudo)
install-deb: deb
	@echo "Installing DEB..."
	sudo dpkg -i $(DEBDIR)/$(PACKAGE_NAME)_$(VERSION)-$(RELEASE)_all.deb || sudo apt-get install -f -y

# Build DEB package
deb:
	@echo "Building DEB package..."
	mkdir -p $(DEBIAN_PKG_DIR)/DEBIAN
	mkdir -p $(DEBIAN_PKG_DIR)/usr/libexec/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/usr/lib/systemd/system
	mkdir -p $(DEBIAN_PKG_DIR)/usr/share/ansible-periodic/playbooks
	mkdir -p $(DEBIAN_PKG_DIR)/etc/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/var/lib/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/var/log/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/usr/share/doc/ansible-periodic-service
	
	# Copy files
	cp $(SCRIPT_FILES) $(DEBIAN_PKG_DIR)/usr/libexec/ansible-periodic/
	chmod 755 $(DEBIAN_PKG_DIR)/usr/libexec/ansible-periodic/run-ansible-periodic.sh
	cp $(SYSTEMD_FILES) $(DEBIAN_PKG_DIR)/usr/lib/systemd/system/
	cp $(CONFIG_FILES) $(DEBIAN_PKG_DIR)/etc/ansible-periodic/
	cp $(PLAYBOOK_FILES) $(DEBIAN_PKG_DIR)/usr/share/ansible-periodic/playbooks/
	cp $(DOC_FILES) $(DEBIAN_PKG_DIR)/usr/share/doc/ansible-periodic-service/
	
	# Create control file
	echo "Package: $(PACKAGE_NAME)" > $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Version: $(VERSION)-$(RELEASE)" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Section: admin" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Priority: optional" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Architecture: all" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Depends: systemd, ansible-core (>= 2.12), podman (>= 4.0)" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Maintainer: Package Maintainer <maintainer@example.com>" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Homepage: https://github.com/your-org/ansible-periodic-service" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo "Description: Systemd service for running Ansible playbooks periodically" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo " A systemd service that runs Ansible playbooks periodically to manage" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo " containerized applications and system configuration. Features include:" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo " - Task management with user repository scanning" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo " - Podman quadlet management for system and user containers" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo " - Vault integration for encrypted variables" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo " - Template processing with Jinja2" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	echo " - Automatic service startup and user lingering" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
	
	# Create postinst script
	echo "#!/bin/bash" > $(DEBIAN_PKG_DIR)/DEBIAN/postinst
	echo "systemctl daemon-reload" >> $(DEBIAN_PKG_DIR)/DEBIAN/postinst
	echo "systemctl enable ansible-periodic.timer" >> $(DEBIAN_PKG_DIR)/DEBIAN/postinst
	echo "systemctl enable ansible-periodic-full.timer" >> $(DEBIAN_PKG_DIR)/DEBIAN/postinst
	chmod 755 $(DEBIAN_PKG_DIR)/DEBIAN/postinst
	
	# Create prerm script
	echo "#!/bin/bash" > $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	echo "if [ \"\$$1\" = \"remove\" ]; then" >> $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	echo "    systemctl stop ansible-periodic.timer" >> $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	echo "    systemctl stop ansible-periodic-full.timer" >> $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	echo "    systemctl disable ansible-periodic.timer" >> $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	echo "    systemctl disable ansible-periodic-full.timer" >> $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	echo "fi" >> $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	chmod 755 $(DEBIAN_PKG_DIR)/DEBIAN/prerm
	
	# Create postrm script
	echo "#!/bin/bash" > $(DEBIAN_PKG_DIR)/DEBIAN/postrm
	echo "if [ \"\$$1\" = \"remove\" ]; then" >> $(DEBIAN_PKG_DIR)/DEBIAN/postrm
	echo "    systemctl daemon-reload" >> $(DEBIAN_PKG_DIR)/DEBIAN/postrm
	echo "fi" >> $(DEBIAN_PKG_DIR)/DEBIAN/postrm
	chmod 755 $(DEBIAN_PKG_DIR)/DEBIAN/postrm
	
	# Build the deb package
	dpkg-deb --build $(DEBIAN_PKG_DIR) $(DEBDIR)/$(PACKAGE_NAME)_$(VERSION)-$(RELEASE)_all.deb
	@echo "DEB package built: $(DEBDIR)/$(PACKAGE_NAME)_$(VERSION)-$(RELEASE)_all.deb"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(TOPDIR) $(DEBDIR)

# Show what files will be packaged
list-files:
	@echo "Systemd unit files:"
	@for file in $(SYSTEMD_FILES); do echo "  $$file"; done
	@echo "Script files:"
	@for file in $(SCRIPT_FILES); do echo "  $$file"; done
	@echo "Configuration files:"
	@for file in $(CONFIG_FILES); do echo "  $$file"; done
	@echo "Playbook files:"
	@for file in $(PLAYBOOK_FILES); do echo "  $$file"; done
	@echo "Documentation files:"
	@for file in $(DOC_FILES); do echo "  $$file"; done

# Validate spec file
validate:
	@echo "Validating spec file..."
	rpmlint $(SPEC_FILE)

# Test install (builds and installs in one step)
test-install: clean rpm install
test-install-deb: clean deb install-deb

help:
	@echo "Available targets:"
	@echo "  all         - Build both RPM and DEB packages (default)"
	@echo "  prepare     - Set up build directories and copy files"
	@echo "  srpm        - Build source RPM"
	@echo "  rpm         - Build binary RPM"
	@echo "  deb         - Build DEB package"
	@echo "  install     - Install the built RPM (requires sudo)"
	@echo "  install-deb - Install the built DEB (requires sudo)"
	@echo "  test-install- Clean, build, and install RPM in one step"
	@echo "  test-install-deb - Clean, build, and install DEB in one step"
	@echo "  clean       - Remove build artifacts"
	@echo "  list-files  - Show files that will be packaged"
	@echo "  validate    - Validate spec file with rpmlint"
	@echo "  help        - Show this help message" 