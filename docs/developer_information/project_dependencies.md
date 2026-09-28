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
| OQS-Provider   | 0.11.0+                | `1670a8a91bbca997d33e6b6851309d6241cc224c` |                                                |
| OpenSSL        | Official release 3.6.1 | N/A                                        | Downloaded as a fixed release tarball          |
| pqax           | Always latest          | N/A                                        | Pulled from latest main branch at install time |

**Note:** These versions are used by default unless the `--latest-dependency-versions` flag is explicitly set during setup.

**Note:** The + sign in the OQS-Provider version indicates that the latest commit from the main branch is used, which may include additional changes beyond the last tagged
release. This is because to utilise Liboqs version 0.16.0, several changes made to OQS-Provider after the 0.11.0 release are required.

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

## Python PIP Dependencies
The following Python packages are required for testing and result parsing. These are automatically checked and installed via pip during setup:

- pandas
- numpy (installed with pandas)
- jinja2
- tabulate
- pyserial

If the system's Python environment is restricted (e.g., due to externally-managed-environment policies), the setup script will offer the option to install packages using the `--break-system-packages` flag. Manual installation is also supported if preferred.