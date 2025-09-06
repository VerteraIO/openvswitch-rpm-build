# Open vSwitch RPM Builder

Build Open vSwitch RPMs for multiple Enterprise Linux distributions using Docker.

## Quick Start

### Single Distribution Build
```bash
# Rocky Linux 10 (default)
make docker-build VERSION=3.6.0

# Rocky Linux 9
make docker-build DISTRO=rocky DISTRO_VERSION=9 VERSION=3.6.0

# AlmaLinux 10
make docker-build DISTRO=alma DISTRO_VERSION=10 VERSION=3.6.0

# RHEL 9
make docker-build DISTRO=rhel DISTRO_VERSION=9 VERSION=3.6.0
```

### Build for All Distributions
```bash
# Build for Rocky, AlmaLinux, and RHEL (versions 9 & 10)
make build-all VERSION=3.6.0
```

## Supported Distributions

| Distribution | Versions | Docker Image |
|--------------|----------|--------------|
| Rocky Linux  | 9, 10    | `rockylinux/rockylinux` |
| AlmaLinux    | 9, 10    | `almalinux/almalinux` |
| RHEL/UBI     | 9, 10    | `registry.access.redhat.com/ubi` |

## Examples

### Build Specific Distribution
```bash
# Rocky Linux 9 with OVS 3.6.0
make docker-build DISTRO=rocky DISTRO_VERSION=9 VERSION=3.6.0

# AlmaLinux 10 with OVS 3.3.0  
make docker-build DISTRO=alma DISTRO_VERSION=10 VERSION=3.3.0
```

### Build All Distributions
```bash
# Creates ./out/rocky9/, ./out/rocky10/, ./out/alma9/, etc.
make build-all VERSION=3.6.0
```

## Host System Build
```bash
# Install dependencies and build on host (Rocky Linux only)
make build VERSION=3.6.0
```

## Output Structure

```
./out/
├── rocky9/          # Rocky Linux 9 RPMs
├── rocky10/         # Rocky Linux 10 RPMs  
├── alma9/           # AlmaLinux 9 RPMs
├── alma10/          # AlmaLinux 10 RPMs
├── rhel9/           # RHEL 9 RPMs
└── rhel10/          # RHEL 10 RPMs
```

## Requirements

- Docker (for container builds)
- Internet connection (to download OVS source)
- For RHEL builds: Valid Red Hat subscription or UBI images

## Supported OVS Versions

- OVS 3.x.x series (downloaded from openvswitch.org)
- Automatic dependency resolution via `dnf builddep`

## AF_XDP (XDP) Support

This builder enables AF_XDP support in the generated RPMs.

- What changed
  - Docker image now installs `libbpf-devel`, `libxdp-devel`, and `numactl-devel`.
  - RPM builds are invoked with `--with afxdp` for the Fedora/RHEL spec.
- How to build (unchanged commands)
  - `make docker-build ...` automatically produces AF_XDP-enabled RPMs.
  - Host builds via `make build` also pass `--with afxdp` to `rpmbuild`.
  - To disable AF_XDP for a particular build, pass `AFXDP=0`:
    - `make docker-build AFXDP=0`
    - `make build AFXDP=0`
- Kernel requirements (at runtime)
  - A kernel with XDP/AF_XDP enabled: `CONFIG_BPF=y`, `CONFIG_BPF_SYSCALL=y`, `CONFIG_XDP_SOCKETS=y`.
  - Optional (performance/debug): `CONFIG_BPF_JIT=y`, `CONFIG_HAVE_EBPF_JIT=y`, `CONFIG_XDP_SOCKETS_DIAG=y`.
- Verify AF_XDP availability
  - Check dependencies in the RPM: `rpm -qp --requires ./out/<distro><ver>/openvswitch-*.rpm | grep -E 'libbpf|libxdp'`.
  - After installing the RPMs and starting userspace datapath, try adding an AF_XDP port:

    ```bash
    # Ensure userspace datapath
    ovs-vsctl -- set Open_vSwitch . other_config:dpdk-init=false
    ovs-vsctl add-br br0 -- set Bridge br0 datapath_type=netdev
    # Use one queue
    ethtool -L <IFACE> combined 1
    ovs-vsctl add-port br0 <IFACE> -- set interface <IFACE> type=afxdp
    ovs-vsctl get interface <IFACE> status:xdp-mode
    ```

For more details, see the official OVS AF_XDP docs: https://docs.openvswitch.org/en/latest/intro/install/afxdp/

## License

This project is licensed under the Apache 2.0 License.

# Run the builder, mounting ./out to collect RPMs from ~/rpmbuild/RPMS
docker run --rm \
  -v $(pwd)/out:/root/rpmbuild/RPMS \
  ovs-rpm-builder:rocky10 3.6.0

# RPMs will be in ./out
ls -la ./out
```

## Customization

You can modify the `build_ovs_rpm.sh` script to:
- Change the default OVS version
- Add custom build options
- Modify RPM build parameters

## Notes

- Source tarballs are downloaded from GitHub tags, e.g. `https://github.com/openvswitch/ovs/archive/refs/tags/v3.6.0.tar.gz`.
- The script enables EPEL and CRB repositories, which are commonly needed on Rocky Linux.
- The build target uses `make rpm-rhel` to match RHEL/Rocky conventions.

## Cleanup

To clean up build files:
```bash
rm -rf /tmp/ovs-build
rm -rf ~/rpmbuild/BUILD/openvswitch-*
```

## License

This project is open source and available under the MIT License.
