# Version v0.4.1 Release
Welcome to the version 0.4.1 release of the PQC-LEO project!

##  Release Overview
The v0.4.1 release focuses on project restructuring and clarity improvements. Most notably, the repository has been renamed from pqc-evaluation-tools to PQC-LEO (PQC-Library Evaluation Operator). All documentation, script comments, and references have been updated to reflect the new name.

A migration notice has been added to the main README to assist users in updating their local clones. This notice will remain until the release of v0.5.0.

Additionally, minor updates were made to the project documentation and script files to provide greater clarity on the memory metrics collected by the framework.

## Project Features
The project provides automation for:

- Compiling and configuration of the OQS, ARM PMU, and OpenSSL dependency libraries.

- Gathering PQC computational performance data, including CPU and memory usage metrics using the Liboqs library.

- Gathering Networking performance data for the integration of PQC schemes in the TLS 1.3  protocol by utilising the OpenSSL 3.5.0 and OQS-Provider libraries.

- Coordinated testing of PQC TLS handshakes using either the loopback interface or a physical network connection between a server and client device.

- Automatic or manual parsing of raw performance data, including calculating averages across multiple test runs.

## Change Log 
* Rename repository to PQC-LEO and update references in [#70](https://github.com/crt26/PQC-LEO/pull/70)
* Clarify memory metric terminology across docs and scripts in [#73](https://github.com/crt26/PQC-LEO/pull/73)

**Full Changelog**: https://github.com/crt26/PQC-LEO/compare/v0.4.0...v0.4.1

## Important Notes

- HQC algorithms are disabled by default in both liboqs and OQS-Provider due to non-conformance with the latest algorithm implementation, which includes crucial security fixes. The PQC-LEO framework includes an optional mechanism to enable HQC for **benchmarking purposes only**, with explicit user confirmation required. For more information, refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) guide and the project's [DISCLAIMER](./DISCLAIMER.md) document.

- Functionality is limited to Debian-based operating systems.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be seen in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.
  
## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)

We look forward to your feedback and contributions to this project!
