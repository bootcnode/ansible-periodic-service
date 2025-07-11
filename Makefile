PACKAGE_NAME = ansible-periodic-service
VERSION = 1.2.3
RELEASE = 1
ARCH = noarch

# Container image name
CONTAINER_IMAGE = ansible-periodic-builder

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
SPEC_FILE = $(SPECDIR)/ansible-periodic-service.spec

# DEB build directories
DEBDIR = $(shell pwd)/debbuild
DEBIAN_PKG_DIR = $(DEBDIR)/$(PACKAGE_NAME)_$(VERSION)-$(RELEASE)

# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Set upload defaults if not defined in .env
UPLOAD_TIMEOUT ?= 300
UPLOAD_VERBOSE ?= false

.PHONY: all clean rpm srpm prepare install deb build-container upload-rpm upload-deb upload-all check-env

all: rpm deb

# Build the container image
build-container:
	@echo "Building container image..."
	podman build -t $(CONTAINER_IMAGE) .

# Create RPM build directory structure
prepare:
	@echo "Creating RPM build directories..."
	mkdir -p $(SOURCEDIR) $(SPECDIR) $(RPMDIR) $(SRPMDIR) $(BUILDDIR)
	@echo "Source files are already in place in $(SOURCEDIR)"

# Build source RPM using container
srpm: build-container prepare
	@echo "Building source RPM in container..."
	podman run --rm -v $(SRPMDIR):/output:Z $(CONTAINER_IMAGE) \
		sh -c "cd /home/builder/periodic-ansible-service && \
		       rpmbuild --define '_topdir /home/builder/periodic-ansible-service/rpmbuild' \
		               --define 'version $(VERSION)' \
		               --define 'release $(RELEASE)' \
		               -bs rpmbuild/SPECS/ansible-periodic-service.spec && \
		       cp rpmbuild/SRPMS/*.src.rpm /output/"

# Build binary RPM using container
rpm: build-container prepare
	@echo "Building binary RPM in container..."
	podman run --rm -v $(RPMDIR):/output:Z -v $(SRPMDIR):/srpms:Z $(CONTAINER_IMAGE) \
		sh -c "cd /home/builder/periodic-ansible-service && \
		       rpmbuild --define '_topdir /home/builder/periodic-ansible-service/rpmbuild' \
		               --define 'version $(VERSION)' \
		               --define 'release $(RELEASE)' \
		               -bs rpmbuild/SPECS/ansible-periodic-service.spec && \
		       cp rpmbuild/SRPMS/*.src.rpm /srpms/ && \
		       rpmbuild --define '_topdir /home/builder/periodic-ansible-service/rpmbuild' \
		               --define 'version $(VERSION)' \
		               --define 'release $(RELEASE)' \
		               --rebuild rpmbuild/SRPMS/*.src.rpm && \
		       cp -r rpmbuild/RPMS/* /output/"

# Build DEB package using container
deb: build-container
	@echo "Building DEB package in container..."
	mkdir -p $(DEBDIR)
	podman run --rm -v $(DEBDIR):/output:Z $(CONTAINER_IMAGE) \
		sh -c "cd /home/builder/periodic-ansible-service && \
		       make deb-internal DEBDIR=/output"

# Internal DEB build target (runs inside container)
deb-internal:
	@echo "Building DEB package..."
	$(eval DEBDIR ?= $(shell pwd)/debbuild)
	$(eval DEBIAN_PKG_DIR = $(DEBDIR)/$(PACKAGE_NAME)_$(VERSION)-$(RELEASE))
	mkdir -p $(DEBIAN_PKG_DIR)/DEBIAN
	mkdir -p $(DEBIAN_PKG_DIR)/usr/libexec/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/usr/lib/systemd/system
	mkdir -p $(DEBIAN_PKG_DIR)/usr/share/ansible-periodic/playbooks
	mkdir -p $(DEBIAN_PKG_DIR)/etc/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/var/lib/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/var/log/ansible-periodic
	mkdir -p $(DEBIAN_PKG_DIR)/usr/share/doc/ansible-periodic-service
	
	# Copy files from SOURCES directory
	$(eval CONTAINER_SOURCEDIR = /home/builder/periodic-ansible-service/rpmbuild/SOURCES)
	cp $(CONTAINER_SOURCEDIR)/$(SCRIPT_FILES) $(DEBIAN_PKG_DIR)/usr/libexec/ansible-periodic/
	chmod 755 $(DEBIAN_PKG_DIR)/usr/libexec/ansible-periodic/run-ansible-periodic.sh
	cp $(CONTAINER_SOURCEDIR)/ansible-periodic@.service $(CONTAINER_SOURCEDIR)/ansible-periodic.service $(CONTAINER_SOURCEDIR)/ansible-periodic.timer $(CONTAINER_SOURCEDIR)/ansible-periodic-full.timer $(DEBIAN_PKG_DIR)/usr/lib/systemd/system/
	cp $(CONTAINER_SOURCEDIR)/$(CONFIG_FILES) $(DEBIAN_PKG_DIR)/etc/ansible-periodic/
	cp $(CONTAINER_SOURCEDIR)/$(PLAYBOOK_FILES) $(DEBIAN_PKG_DIR)/usr/share/ansible-periodic/playbooks/
	cp $(CONTAINER_SOURCEDIR)/$(DOC_FILES) $(DEBIAN_PKG_DIR)/usr/share/doc/ansible-periodic-service/
	
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
	echo " - Variable integration with hierarchical vars.yml support" >> $(DEBIAN_PKG_DIR)/DEBIAN/control
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

# Install the built RPM (requires sudo)
install: rpm
	@echo "Installing RPM..."
	sudo dnf install -y $(RPMDIR)/$(ARCH)/$(PACKAGE_NAME)-$(VERSION)-$(RELEASE).$(ARCH).rpm

# Install the built DEB (requires sudo)
install-deb: deb
	@echo "Installing DEB..."
	sudo dpkg -i $(DEBDIR)/$(PACKAGE_NAME)_$(VERSION)-$(RELEASE)_all.deb || sudo apt-get install -f -y

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILDDIR) $(RPMDIR) $(SRPMDIR) $(TOPDIR)/BUILDROOT $(DEBDIR)

# Clean everything including source structure
clean-all:
	@echo "Cleaning all build artifacts and directories..."
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

# Validate spec file using container
validate: build-container
	@echo "Validating spec file in container..."
	podman run --rm $(CONTAINER_IMAGE) \
		sh -c "cd /home/builder/periodic-ansible-service && \
		       rpmlint --define 'version $(VERSION)' \
		              --define 'release $(RELEASE)' \
		              rpmbuild/SPECS/ansible-periodic-service.spec"

# Test install (builds and installs in one step)
test-install: clean rpm install
test-install-deb: clean deb install-deb

# Check if environment variables are set for upload
check-env:
	@if [ -z "$(REPO_USERNAME)" ] || [ -z "$(REPO_PASSWORD)" ]; then \
		echo "Error: REPO_USERNAME and REPO_PASSWORD must be set in .env file"; \
		echo "Copy env.sample to .env and configure your repository credentials"; \
		exit 1; \
	fi
	@if [ -z "$(RPM_UPLOAD_URL)" ]; then \
		echo "Error: RPM_UPLOAD_URL must be set in .env file"; \
		exit 1; \
	fi
	@if [ -z "$(DEB_UPLOAD_URL)" ]; then \
		echo "Error: DEB_UPLOAD_URL must be set in .env file"; \
		exit 1; \
	fi

# Upload RPM package to repository
upload-rpm: check-env
	@echo "Checking for RPM package..."
	@RPM_FILE=$$(find $(RPMDIR) -name "$(PACKAGE_NAME)-$(VERSION)-$(RELEASE).$(ARCH).rpm" | head -1); \
	if [ -z "$$RPM_FILE" ]; then \
		echo "Error: RPM package not found. Run 'make rpm' first."; \
		exit 1; \
	fi; \
	echo "Uploading RPM package: $$RPM_FILE"; \
	echo "Package: $(PACKAGE_NAME)-$(VERSION)-$(RELEASE).$(ARCH).rpm"; \
	echo "Target URL: $(RPM_UPLOAD_URL)"; \
	CURL_OPTS="--user $(REPO_USERNAME):$(REPO_PASSWORD) --max-time $(UPLOAD_TIMEOUT) --show-error --write-out '%{http_code}'"; \
	if [ "$(UPLOAD_VERBOSE)" = "true" ]; then \
		CURL_OPTS="$$CURL_OPTS --verbose"; \
	else \
		CURL_OPTS="$$CURL_OPTS --silent"; \
	fi; \
	CURL_CMD="curl $$CURL_OPTS --upload-file \"$$RPM_FILE\" \"$(RPM_UPLOAD_URL)\""; \
	echo "Executing: $$CURL_CMD"; \
	HTTP_CODE=$$(eval $$CURL_CMD); \
	echo "HTTP Response Code: $$HTTP_CODE"; \
	case "$$HTTP_CODE" in \
		200|201) echo "✅ Successfully uploaded RPM package (HTTP $$HTTP_CODE)";; \
		409) echo "⚠️  Package already exists in repository (HTTP 409)"; \
		     echo "This usually means $(PACKAGE_NAME)-$(VERSION)-$(RELEASE) is already uploaded"; \
		     echo "Consider incrementing the version or release number"; \
		     exit 0;; \
		401|403) echo "❌ Authentication failed (HTTP $$HTTP_CODE)"; \
		         echo "Check your REPO_USERNAME and REPO_PASSWORD in .env file"; \
		         exit 1;; \
		404) echo "❌ Repository endpoint not found (HTTP $$HTTP_CODE)"; \
		     echo "Check your RPM_UPLOAD_URL in .env file"; \
		     exit 1;; \
		*) echo "❌ Upload failed with HTTP code '$$HTTP_CODE'"; \
		   echo "This may indicate a server error or configuration issue"; \
		   exit 1;; \
	esac

# Upload DEB package to repository
upload-deb: check-env
	@echo "Checking for DEB package..."
	@DEB_FILE=$$(find $(DEBDIR) -name "$(PACKAGE_NAME)_$(VERSION)-$(RELEASE)_all.deb" | head -1); \
	if [ -z "$$DEB_FILE" ]; then \
		echo "Error: DEB package not found. Run 'make deb' first."; \
		exit 1; \
	fi; \
	echo "Uploading DEB package: $$DEB_FILE"; \
	echo "Package: $(PACKAGE_NAME)_$(VERSION)-$(RELEASE)_all.deb"; \
	echo "Target URL: $(DEB_UPLOAD_URL)"; \
	CURL_OPTS="--user $(REPO_USERNAME):$(REPO_PASSWORD) --max-time $(UPLOAD_TIMEOUT) --show-error --write-out '%{http_code}'"; \
	if [ "$(UPLOAD_VERBOSE)" = "true" ]; then \
		CURL_OPTS="$$CURL_OPTS --verbose"; \
	else \
		CURL_OPTS="$$CURL_OPTS --silent"; \
	fi; \
	CURL_CMD="curl $$CURL_OPTS --upload-file \"$$DEB_FILE\" \"$(DEB_UPLOAD_URL)\""; \
	echo "Executing: $$CURL_CMD"; \
	HTTP_CODE=$$(eval $$CURL_CMD); \
	echo "HTTP Response Code: $$HTTP_CODE"; \
	case "$$HTTP_CODE" in \
		200|201) echo "✅ Successfully uploaded DEB package (HTTP $$HTTP_CODE)";; \
		409) echo "⚠️  Package already exists in repository (HTTP 409)"; \
		     echo "This usually means $(PACKAGE_NAME)_$(VERSION)-$(RELEASE) is already uploaded"; \
		     echo "Consider incrementing the version or release number"; \
		     exit 0;; \
		401|403) echo "❌ Authentication failed (HTTP $$HTTP_CODE)"; \
		         echo "Check your REPO_USERNAME and REPO_PASSWORD in .env file"; \
		         exit 1;; \
		404) echo "❌ Repository endpoint not found (HTTP $$HTTP_CODE)"; \
		     echo "Check your DEB_UPLOAD_URL in .env file"; \
		     exit 1;; \
		*) echo "❌ Upload failed with HTTP code '$$HTTP_CODE'"; \
		   echo "This may indicate a server error or configuration issue"; \
		   exit 1;; \
	esac

# Upload both RPM and DEB packages
upload-all: upload-rpm upload-deb
	@echo "All packages uploaded successfully"

# Build and upload RPM in one step
build-upload-rpm: rpm upload-rpm

# Build and upload DEB in one step
build-upload-deb: deb upload-deb

# Build and upload all packages in one step
build-upload-all: all upload-all

# Show current version information
show-version:
	@echo "Current package version information:"
	@echo "  Package: $(PACKAGE_NAME)"
	@echo "  Version: $(VERSION)"
	@echo "  Release: $(RELEASE)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Full package name: $(PACKAGE_NAME)-$(VERSION)-$(RELEASE).$(ARCH)"

help:
	@echo "Available targets:"
	@echo "  all                - Build both RPM and DEB packages (default)"
	@echo "  build-container    - Build the container image for packaging"
	@echo "  prepare            - Set up build directories"
	@echo "  srpm               - Build source RPM using container"
	@echo "  rpm                - Build binary RPM using container"
	@echo "  deb                - Build DEB package using container"
	@echo "  install            - Install the built RPM (requires sudo)"
	@echo "  install-deb        - Install the built DEB (requires sudo)"
	@echo "  test-install       - Clean, build, and install RPM in one step"
	@echo "  test-install-deb   - Clean, build, and install DEB in one step"
	@echo "  check-env          - Check if upload environment variables are set"
	@echo "  upload-rpm         - Upload RPM package to repository"
	@echo "  upload-deb         - Upload DEB package to repository"
	@echo "  upload-all         - Upload both RPM and DEB packages"
	@echo "  build-upload-rpm   - Build and upload RPM in one step"
	@echo "  build-upload-deb   - Build and upload DEB in one step"
	@echo "  build-upload-all   - Build and upload all packages in one step"
	@echo "  show-version       - Display current version information"
	@echo "  clean              - Remove build artifacts (preserves source structure)"
	@echo "  clean-all          - Remove all build artifacts and directories"
	@echo "  list-files         - Show files that will be packaged"
	@echo "  validate           - Validate spec file with rpmlint using container"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Upload Configuration:"
	@echo "  Copy env.sample to .env and configure your repository settings"
	@echo "  Required variables: REPO_USERNAME, REPO_PASSWORD, RPM_UPLOAD_URL, DEB_UPLOAD_URL" 
