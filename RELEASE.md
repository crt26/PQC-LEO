# Version v0.4.2 Release
Welcome to the version 0.4.2 release of the PQC-LEO project!

## Release Overview
The v0.4.2 release provides a bug fix for the TLS classical handshake parsing logic.

An issue was identified in the parsing scripts where session ID reuse results for classical TLS handshakes were incorrectly averaged during post-processing. This affected the accuracy of averaged networking performance metrics when analysing TLS benchmarking outputs.

This release corrects the averaging behaviour so that session ID reuse results are calculated using only the appropriate dataset.

No new features or structural changes are included in this release.

## Change Log
- Fix incorrect averaging of TLS classical session reuse results in [#84](https://github.com/crt26/PQC-LEO/pull/84)

**Full Changelog**: https://github.com/crt26/PQC-LEO/compare/v0.4.1...v0.4.2

## Important Notes

- HQC algorithms remain disabled by default in both liboqs and OQS-Provider due to non-conformance with the latest algorithm implementation, which includes crucial security fixes. The PQC-LEO framework includes an optional mechanism to enable HQC for **benchmarking purposes only**, with explicit user confirmation required. For more information, refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) guide and the project's [DISCLAIMER](./DISCLAIMER.md) document.

- Functionality is limited to Debian-based operating systems.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be seen in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.

## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)
