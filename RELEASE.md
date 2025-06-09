# Version v0.4.0 Release
Welcome to the version 0.4.0 release of the PQC-Evaluation-Tools project!

##  Release Overview
The version 0.4.0 release of the PQC-Evaluation-Tools suite delivers expanded functionality, improved stability, and better alignment with the latest set of PQC implementations available. This release upgrades the project to support OpenSSL 3.5.0 and the native PQC algorithms it supports, improves project stability with changes to the automated setup process, and updates all OQS-related dependencies to their latest stable versions.

Script naming and structure have been streamlined to reflect the broader set of PQC schemes that are now supported. Parsing of performance results has also been enhanced to provide greater flexibility and now runs automatically after testing has completed. Dependency management is now more robust, with verified versions used by default to avoid upstream instability.

Finally, project documentation has been reviewed and expanded to reflect recent changes in PQC sources and now includes additional guidance to improve usability.

These updates strengthen the project's stability and extend its support for a broader range of PQC implementations.

## Project Features
The project provides automation for:

- Compiling and configuration of the OQS, ARM PMU, and OpenSSL dependency libraries.

- Gathering PQC computational performance data, including CPU and memory usage metrics using the Liboqs library.

- Gathering Networking performance data for the integration of PQC schemes in the TLS 1.3  protocol by utilising the OpenSSL 3.5.0 and OQS-Provider libraries.

- Coordinated testing of PQC TLS handshakes using either the loopback interface or a physical network connection between a server and client device.

- Automatic or manual parsing of raw performance data, including calculating averages across multiple test runs.

## Change Log 
* Upgrade OpenSSL Dependency to Version 3.5.0 in [#55](https://github.com/crt26/pqc-evaluation-tools/pull/55)
* Improve Dependency Stability by Defaulting to Verified Version in [#56](https://github.com/crt26/pqc-evaluation-tools/pull/56)
* Improve Result Parsing Functionality and Flexibility in [#57](https://github.com/crt26/pqc-evaluation-tools/pull/57)
* Align script names and documentation with expanded PQC sources in [#59](https://github.com/crt26/pqc-evaluation-tools/pull/59)
* Update OQS Dependencies to Latest Versions and Add Optional HQC Support for TLS Testing in [#61](https://github.com/crt26/pqc-evaluation-tools/pull/61)
* Finalise Documentation for v0.4.0 Release by in [#63](https://github.com/crt26/pqc-evaluation-tools/pull/63)

**Full Changelog**: https://github.com/crt26/pqc-evaluation-tools/compare/v0.3.1...v0.4.0

## Important Notes

- HQC algorithms are disabled by default in both liboqs and OQS-Provider due to non-conformance with the latest algorithm implementation, which includes crucial security fixes. The PQC-Evaluation-Tools project includes an optional mechanism to enable HQC for **benchmarking purposes only**, with explicit user confirmation required. For more information, refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) guide and the project's [DISCLAIMER](./DISCLAIMER.md) document.

- Functionality is limited to Debian-based operating systems.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be seen in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.
  
## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-Evaluation-Tools Project Page](https://github.com/users/crt26/projects/2)


We look forward to your feedback and contributions to this project!
