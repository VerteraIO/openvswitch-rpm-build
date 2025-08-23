# Open vSwitch RPM Builder - Makefile (scriptless)
# Targets:
#   make build           - Build RPMs on host (Rocky Linux 10)
#   make build VERSION=X - Build a specific OVS version
#   make docker-image    - Build the Docker image
#   make docker-build    - Build RPMs inside Docker (outputs to ./out)
#   make docker-build DISTRO=rocky DISTRO_VERSION=9 - Build for Rocky 9
#   make docker-build DISTRO=alma DISTRO_VERSION=10 - Build for AlmaLinux 10
#   make docker-build DISTRO=rhel DISTRO_VERSION=9  - Build for RHEL 9
#   make build-all       - Build for all supported distros/versions
#   make clean           - Remove local build artifacts

SHELL := /bin/bash
# Variables
VERSION ?= 3.6.0
DISTRO ?= rocky
DISTRO_VERSION ?= 10
IMAGE = ovs-rpm-builder:$(DISTRO)$(DISTRO_VERSION)
OUT_DIR = out
BUILD_DIR = build
RPM_DIR = $(BUILD_DIR)/rpms

.PHONY: build deps src rpm docker-image docker-build build-all clean

# Compute SUDO dynamically
SUDO := $(shell [ "$$(id -u)" -eq 0 ] && echo "" || echo "sudo")

build: deps src rpm
	@echo "RPMs available under $(RPM_DIR)"

deps:
	$(SUDO) dnf install -y dnf-plugins-core epel-release
	$(SUDO) bash -lc 'crb enable || dnf config-manager --set-enabled crb || true'
	$(SUDO) dnf groupinstall -y "Development Tools"
	$(SUDO) dnf install -y \
	  rpm-build rpmdevtools \
	  openssl-devel python3-devel kernel-devel \
	  libtool libcap-ng-devel \
	  selinux-policy-devel \
	  python3-sphinx python3-six \
	  checkpolicy libpcap-devel libcmocka-devel \
	  unbound-devel libunwind-devel \
	  redhat-rpm-config elfutils-libelf-devel \
	  autoconf automake pkgconfig wget

src:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && rpmdev-setuptree
	cd $(BUILD_DIR) && curl -fL -o v$(VERSION).tar.gz https://github.com/openvswitch/ovs/archive/refs/tags/v$(VERSION).tar.gz
	cd $(BUILD_DIR) && tar xfz v$(VERSION).tar.gz

rpm:
	cd $(BUILD_DIR)/ovs-$(VERSION) && { \
	  if [ ! -x ./configure ]; then echo "Bootstrapping (./boot.sh)..."; ./boot.sh; fi; \
	  ./configure; \
	  make dist; \
	  cp openvswitch-$(VERSION).tar.gz $(HOME)/rpmbuild/SOURCES/; \
	  sed -e '/^%package devel/,/^%package selinux-policy/{ /^%package selinux-policy/!d; }' -e '/^%files devel/,/^%files selinux-policy/{ /^%files selinux-policy/!d; }' -e '/rm -rf.*usr\/include/a\\rm -f $$RPM_BUILD_ROOT/usr/lib*/lib*.so $$RPM_BUILD_ROOT/usr/lib*/lib*.a $$RPM_BUILD_ROOT/usr/lib*/pkgconfig/lib*.pc\nrm -rf $$RPM_BUILD_ROOT/usr/share/openvswitch/scripts/usdt/' rhel/openvswitch.spec > $(HOME)/rpmbuild/SPECS/openvswitch.spec; \
	  rpmbuild -bb --without check --define "_without_devel 1" --define "_topdir $(HOME)/rpmbuild" $(HOME)/rpmbuild/SPECS/openvswitch.spec; \
	}
	mkdir -p $(RPM_DIR)
	cp -v $(HOME)/rpmbuild/RPMS/*/*.rpm $(RPM_DIR)

docker-image:
	docker build --build-arg DISTRO=$(DISTRO) --build-arg DISTRO_VERSION=$(DISTRO_VERSION) -t $(IMAGE) .

docker-build: docker-image
	mkdir -p $(OUT_DIR)/$(DISTRO)$(DISTRO_VERSION)
	docker run --rm -v $(PWD)/$(OUT_DIR)/$(DISTRO)$(DISTRO_VERSION):/root/rpmbuild/RPMS \
	  $(IMAGE) bash -lc " \
	    set -e && \
	    dnf install -y dnf-plugins-core epel-release && \
	    (crb enable || dnf config-manager --set-enabled crb || dnf config-manager --set-enabled powertools || true) && \
	    dnf clean metadata && \
	    dnf groupinstall -y \"Development Tools\" && \
	    dnf install -y rpm-build rpmdevtools python3-netaddr python3-pyparsing && \
	    rpmdev-setuptree && \
	    curl -fL -o /root/rpmbuild/SOURCES/openvswitch-$(VERSION).tar.gz https://www.openvswitch.org/releases/openvswitch-$(VERSION).tar.gz && \
	    cd /root/rpmbuild/SOURCES && \
	    tar -zxf openvswitch-$(VERSION).tar.gz && \
	    dnf builddep -y openvswitch-$(VERSION)/rhel/openvswitch-fedora.spec && \
	    rpmbuild -bb --nocheck /root/rpmbuild/SOURCES/openvswitch-$(VERSION)/rhel/openvswitch-fedora.spec && \
	    cp -v /root/rpmbuild/RPMS/*/*.rpm /root/rpmbuild/RPMS \
	  "
	@echo "RPMs available under ./$(OUT_DIR)/$(DISTRO)$(DISTRO_VERSION)"

build-all: clean
	@echo "Building OVS $(VERSION) for all supported distributions..."
	@for distro in rocky alma rhel; do \
		for version in 9 10; do \
			echo "Building for $$distro $$version..."; \
			if make docker-build DISTRO=$$distro DISTRO_VERSION=$$version; then \
				echo "✓ $$distro $$version build complete"; \
			else \
				echo "✗ $$distro $$version build failed"; \
				rmdir $(OUT_DIR)/$$distro$$version 2>/dev/null || true; \
			fi; \
		done; \
	done
	@echo "All builds complete!"
	@for dir in $(OUT_DIR)/*/; do \
		if [ -d "$$dir" ]; then \
			distro=$$(basename "$$dir"); \
			count=$$(ls "$$dir"*.rpm 2>/dev/null | wc -l); \
			echo "$$distro: $$count RPMs in $$dir"; \
		fi; \
	done

clean:
	rm -rf $(OUT_DIR)
	rm -rf $(BUILD_DIR)
