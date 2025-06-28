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

.PHONY: all clean rpm srpm prepare install

all: rpm

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
	rpmbuild --define "_topdir $(TOPDIR)" --rebuild $(SRPMDIR)/$(PACKAGE_NAME)-$(VERSION)-$(RELEASE).*.src.rpm

# Install the built RPM (requires sudo)
install: rpm
	@echo "Installing RPM..."
	sudo dnf install -y $(RPMDIR)/$(ARCH)/$(PACKAGE_NAME)-$(VERSION)-$(RELEASE).*.$(ARCH).rpm

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(TOPDIR)

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

help:
	@echo "Available targets:"
	@echo "  all         - Build RPM package (default)"
	@echo "  prepare     - Set up build directories and copy files"
	@echo "  srpm        - Build source RPM"
	@echo "  rpm         - Build binary RPM"
	@echo "  install     - Install the built RPM (requires sudo)"
	@echo "  test-install- Clean, build, and install in one step"
	@echo "  clean       - Remove build artifacts"
	@echo "  list-files  - Show files that will be packaged"
	@echo "  validate    - Validate spec file with rpmlint"
	@echo "  help        - Show this help message" 