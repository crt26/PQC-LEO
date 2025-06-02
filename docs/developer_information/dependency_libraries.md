# Dependency Libraries

This document lists the **specific commits** used as the last tested versions of the project's core dependencies. These versions are pinned by default during setup to ensure compatibility with the PQC-Evaluation-Tools benchmarking framework.

## Last Tested Versions

| **Dependency** | **Version Context**    | **Commit SHA**                             | **Notes**                                        |
|----------------|------------------------|--------------------------------------------|--------------------------------------------------|
| Liboqs         | Post-0.13.0            | `b75bfb8c56d23a92227b04c096f0264b992de874` | Commit after 0.13.0 release, before 0.14.0       |
| OQS-Provider   | Pre-0.9.0              | `f8cb2c8307e4c95c5bb20f738f3e8a865e5a3ad9` | Commit after 0.8.0, not yet part of 0.9.0 tag    |
| OpenSSL        | Official release 3.5.0 | N/A                                        | Downloaded as a fixed release tarball            |
| pqax           | Always latest          | N/A                                        | Pulled from latest `main` branch at install time |

> **Note:** These versions are used by default unless the `--latest-dependency-versions` flag is explicitly set during setup.

For installation instructions, see the [Installation Instructions](../README.md#installation-instructions).
