FROM fedora:39

# Install build tools for both RPM and DEB
RUN dnf -y update && \
    dnf -y install rpm-build rpmlint make git \
                   dpkg-dev dpkg fakeroot \
                   ruby ruby-devel gcc redhat-rpm-config \
                   rubygems && \
    gem install --no-document fpm

# Set up build user (optional, for non-root builds)
RUN useradd -m builder
WORKDIR /home/builder


# Copy your project in
COPY . /home/builder/periodic-ansible-service
WORKDIR /home/builder/periodic-ansible-service

# Entrypoint: drop to shell, or run make
CMD ["/bin/bash"]