# Project Dependencies <!-- omit from toc -->

## Document Overview <!-- omit from toc -->
This document provides a comprehensive overview of the dependencies used by the PQC-LEO framework. Installation and management of these dependencies are fully automated and handled during execution of the main setup script.

While this information is primarily intended for developers and contributors who need insight into the project's build and runtime environment, it may also be helpful for users who wish to override the default cryptographic library versions.

This document outlines:
- The required system hardware and operating systems
- The specific cryptographic libraries used for benchmarking
- The system-level packages required for compiling and testing
- The Python packages needed for parsing and data processing.

This information helps clarify which software components the project relies on and how the setup script maintains a consistent, reproducible environment. It also includes notes on default versions and how to use alternatives if needed.

### Contents <!-- omit from toc -->
- [Required Hardware and Operating Systems](#required-hardware-and-operating-systems)
- [Cryptographic Dependency Libraries](#cryptographic-dependency-libraries)
- [System Package Dependencies](#system-package-dependencies)
- [OpenSSL Compatibility for Energy Tools](#openssl-compatibility-for-energy-tools)
- [Python PIP Dependencies](#python-pip-dependencies)

## Required Hardware and Operating Systems
PQC-LEO is currently only supported in the following environments:

- x86 Linux Machines using a Debian-based operating system
- ARM Linux devices using a 64-bit Debian-based Operating System

## Cryptographic Dependency Libraries
This section lists the **last tested versions** of the project's core dependencies. These versions are pinned by default during setup to ensure compatibility with the PQC-LEO benchmarking framework.

### Last Tested Versions <!-- omit from toc -->

| **Dependency** | **Version Number**     | **Commit SHA**                             | **Notes**                                      |
|----------------|------------------------|--------------------------------------------|------------------------------------------------|
| Liboqs         | 0.16.0                 | `5a1a854b0dc9f2141bdc771c555ee60c37950183` |                                                |
| OQS-Provider   | 0.12.0                 | `7e9d095aff7967fab9a8ce693e3da5357dc59d58` |                                                |
| OpenSSL        | Official release 4.0.3 | N/A                                        | Downloaded as a fixed release tarball          |
| pqax           | Always latest          | N/A                                        | Pulled from latest main branch at install time |

**Note:** The `--latest-dependency-versions` flag selects the latest OQS library versions. The PQC-LEO OpenSSL build remains fixed at 4.0.3; the energy tools can also use compatible system OpenSSL as described [below](#openssl-compatibility-for-energy-tools).

For setup instructions and details on using the latest cryptographic dependency versions,  please see:

- [README Installation Instructions](../../README.md#installation-instructions)
- [Advanced Setup Configuration](../advanced_setup_configuration.md)

## System Package Dependencies
The following system-level packages are required for building and running the PQC-LEO framework. These are automatically checked and installed using the apt package manager during the setup process.

By default, the setup script will install the latest available versions of these packages from the distribution's package repositories if they are not already present on the system.

- git
- astyle
- cmake
- gcc
- ninja-build
- libssl-dev
- python3-pytest
- python3-pytest-xdist
- unzip
- xsltproc
- doxygen
- graphviz
- python3-yaml
- valgrind
- libtool
- make
- net-tools
- python3-pip
- netcat-openbsd
- libserialport-dev

## OpenSSL Compatibility for Energy Tools
When installing the energy tools, all installation modes use the same OpenSSL selection process. The tools can use either the system OpenSSL installation or the PQC-LEO **OpenSSL 4.0.3** build. The system option requires `libssl-dev` version **3.3.0 or newer**. If this package is missing during the configuration prompts, the system option remains available because the setup script installs and validates it during the dependency installation stage. If `libssl-dev` is unavailable or still does not meet the minimum version requirement after this stage, the PQC-LEO OpenSSL build must be used. Installation modes 1–3 still require the PQC-LEO project OpenSSL independently for the OQS libraries.

If the PQC-LEO OpenSSL build is selected for the energy tools, the build process reuses `lib/openssl_4.0.3` when available, or downloads and builds it as needed. Binaries linked against this version require the corresponding `libssl.so` and `libcrypto.so` libraries to be available at runtime.

The provided `energy_metric_collector.sh` and `pqc_performance_energy_test.sh` scripts handle this automatically when the PQC-LEO OpenSSL build is used. They add the project OpenSSL library directory to `LD_LIBRARY_PATH` while preserving any existing paths. When running the energy tools manually with the project's OpenSSL build or another custom OpenSSL installation, users must ensure that the appropriate library directory is included in `LD_LIBRARY_PATH`, or the equivalent environment variable for the target platform.

For further configuration details, please see the [Energy Collector Tool Usage Guide](../project_tools_guides/energy_collector_usage_guide.md#building-the-energy-usage-collector-tools) and the [Computational Energy Tester Tool Usage Guide](../project_tools_guides/comp_energy_tester_usage_guide.md#setting-up-the-computational-energy-usage-testing-tool).

## Python PIP Dependencies
The following Python packages are required for testing and result parsing. These are automatically checked and installed via pip during setup:

- pandas
- numpy (installed with pandas)
- jinja2
- tabulate
- pyserial

If the system's Python environment is restricted (e.g., due to externally-managed-environment policies), the setup script will offer the option to install packages using the `--break-system-packages` flag. Manual installation is also supported if preferred.
