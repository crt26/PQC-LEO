# Version v0.5.1 Release
Welcome to the version 0.5.1 release of the PQC-LEO project!

## Release Overview
The version 0.5.1 release of PQC-LEO is a minor hotfix that corrects a discrepancy in the project’s supported algorithm documentation.

## Change Log
- Fix mistake in OpenSSL supported KEM algs table in [#93](https://github.com/crt26/PQC-LEO/pull/93)

**Full Changelog**: https://github.com/crt26/PQC-LEO/compare/v0.5.0...v0.5.1

## Important Notes
- HQC algorithms remain disabled by default in both liboqs and OQS-Provider due to non-conformance with the latest algorithm implementation, which includes crucial security fixes. The PQC-LEO framework includes an optional mechanism to enable HQC for **benchmarking purposes only**, with explicit user confirmation required. For more information, refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) guide and the project's [DISCLAIMER](./DISCLAIMER.md) document.

- Functionality is limited to Debian-based operating systems.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be seen in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.

- The project dependencies used in PQC-LEO v0.5.1 include a known issue where certain signature/KEM combinations may produce `inf` values for "Connections Per User Second" in TLS handshake tests with small testing windows. See the [TLS Handshake Inf Result Handling](./docs/performance_results/tls_handshake_inf_result_handling.md) documentation.

## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)
