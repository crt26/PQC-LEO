# Project Dependencies <!-- omit from toc -->

## Document Overview <!-- omit from toc -->
This document provides a comprehensive overview of the dependencies required to build and run the PQC-LEO suite. Installation and management of these dependencies are fully automated and handled during execution of the main setup script.

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
The automated testing tool is currently only supported in the following environments:

- x86 Linux Machines using a Debian-based operating system
- ARM Linux devices using a 64-bit Debian-based Operating System

## Cryptographic Dependency Libraries
This document lists the **specific commits** used as the last tested versions of the project's core dependencies. These versions are pinned by default during setup to ensure compatibility with the PQC-LEO benchmarking framework.

### Last Tested Versions <!-- omit from toc -->

| **Dependency** | **Version Context**    | **Commit SHA**                             | **Notes**                                      |
|----------------|------------------------|--------------------------------------------|------------------------------------------------|
| Liboqs         | Post-0.13.0            | `9aa76bc1309a9bc10061ec3aa07d727c030c9a86` | Commit after 0.13.0 release, before 0.14.0     |
| OQS-Provider   | Post-0.9.0             | `2cc8dd3d3ef8764fa432f87a0ae15431d86bfa90` | Commit after 0.9.0 release                     |
| OpenSSL        | Official release 3.5.0 | N/A                                        | Downloaded as a fixed release tarball          |
| pqax           | Always latest          | N/A                                        | Pulled from latest main branch at install time |

**Note:** These versions are used by default unless the `--latest-dependency-versions` flag is explicitly set during setup.

For setup instructions and details on using the latest cryptographic dependency versions,  please see:

- [Installation Instructions](../../README.md#installation-instructions) section in the main README.
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

## Python PIP Dependencies
The following Python packages are required for testing and result parsing. These are automatically checked and installed via pip during setup:

- pandas
- jinja2
- tabulate

If the system's Python environment is restricted (e.g., due to externally-managed-environment policies), the setup script will offer the option to install packages using the `--break-system-packages` flag. Manual installation is also supported if preferred.