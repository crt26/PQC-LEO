# Dependency Libraries
This document lists the **specific commits** used as the last tested versions of the project's core dependencies. These versions are pinned by default during setup to ensure compatibility with the PQC-Evaluation-Tools benchmarking framework.

## Last Tested Versions

| **Dependency** | **Version Context**    | **Commit SHA**                             | **Notes**                                      |
|----------------|------------------------|--------------------------------------------|------------------------------------------------|
| Liboqs         | Post-0.13.0            | `9aa76bc1309a9bc10061ec3aa07d727c030c9a86` | Commit after 0.13.0 release, before 0.14.0     |
| OQS-Provider   | Post-0.9.0             | `2cc8dd3d3ef8764fa432f87a0ae15431d86bfa90` | Commit after 0.9.0 release                     |
| OpenSSL        | Official release 3.5.0 | N/A                                        | Downloaded as a fixed release tarball          |
| pqax           | Always latest          | N/A                                        | Pulled from latest main branch at install time |

**Note:** These versions are used by default unless the `--latest-dependency-versions` flag is explicitly set during setup.

For setup instructions and details on using the latest dependency versions,  please see:

- [Installation Instructions](../README.md#installation-instructions) in the main README.
- [Advance Setup Configuration](../advanced_setup_configuration.md)