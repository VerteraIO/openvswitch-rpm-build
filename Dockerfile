ARG DISTRO=rocky
ARG DISTRO_VERSION=10

# Select base image based on distribution
FROM rockylinux/rockylinux:${DISTRO_VERSION} AS rocky
FROM almalinux/almalinux:${DISTRO_VERSION} AS alma  
FROM registry.access.redhat.com/ubi${DISTRO_VERSION}/ubi:latest AS rhel

FROM ${DISTRO}

# Install build dependencies
RUN dnf install -y dnf-plugins-core epel-release \
    && (crb enable || dnf config-manager --set-enabled crb || true) \
    # Development Tools group (group name varies, but this works on Rocky 10)
    && dnf groupinstall -y "Development Tools" \
    # Remaining packages
    && dnf install -y rpm-build rpmdevtools \
    openssl-devel python3-devel kernel-devel \
    libtool libcap-ng-devel \
    selinux-policy-devel \
    python3-sphinx \
    python3-six \
    checkpolicy \
    libpcap-devel \
    libcmocka-devel \
    unbound-devel \
    libunwind-devel \
    redhat-rpm-config \
    elfutils-libelf-devel \
    autoconf automake pkgconfig \
    wget \
    && dnf clean all

# Create build directory
WORKDIR /build
