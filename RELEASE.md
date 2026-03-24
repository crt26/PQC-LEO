# Version v0.5.0 Release
Welcome to the version 0.5.0 release of the PQC-LEO project!

## Release Overview
The version 0.5.0 release of PQC-LEO focuses on dependency updates, improved robustness, and enhancements to result parsing functionality. This release upgrades the project to support OpenSSL 3.6.1 and updates all core OQS dependencies to their latest tested stable versions.

Stability has been improved through enhanced exception handling in the automated setup process, making dependency compilation and configuration more resilient to errors. Performance result processing has also been extended, including the addition of combined average output files for TLS handshake benchmarking and fixes to formatting inconsistencies in computational performance results.

These changes improve reliability and maintain compatibility with the latest PQC dependencies.

## Change Log
- Update Pinned Liboqs dependency to version 0.15.0 in [#78](https://github.com/crt26/PQC-LEO/pull/78)
- Update pinned OQS-Provider dependency to version 0.11.0 in [#81](https://github.com/crt26/PQC-LEO/pull/81)
- Upgrade OpenSSL dependency to 3.6.1 in [#82](https://github.com/crt26/PQC-LEO/pull/82)
- Fix whitespace formatting issue in computational performance CSV results in [#86](https://github.com/crt26/PQC-LEO/pull/86)
- Add combined averages output file for TLS handshake results parsing in [#87](https://github.com/crt26/PQC-LEO/pull/87)
- Improve exception handling for project dependency build process in setup script in [#88](https://github.com/crt26/PQC-LEO/pull/88)
- Tidy project documentation in preparation for v0.5.0 release in [#89](https://github.com/crt26/PQC-LEO/pull/89)

**Full Changelog**: https://github.com/crt26/PQC-LEO/compare/v0.4.2...v0.5.0

## Important Notes
- HQC algorithms remain disabled by default in both liboqs and OQS-Provider due to non-conformance with the latest algorithm implementation, which includes crucial security fixes. The PQC-LEO framework includes an optional mechanism to enable HQC for **benchmarking purposes only**, with explicit user confirmation required. For more information, refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) guide and the project's [DISCLAIMER](./DISCLAIMER.md) document.

- Functionality is limited to Debian-based operating systems.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be seen in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.

- The project dependencies used in PQC-LEO v0.5.0 include a known issue where certain signature/KEM combinations may produce `inf` values for "Connections Per User Second" in TLS handshake tests with small testing windows. See the [TLS Handshake Inf Result Handling](./docs/performance_results/tls_handshake_inf_result_handling.md) documentation.

## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)
