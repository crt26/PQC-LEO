# PQC-LEO v0.6.1 Release
Welcome to the version 0.6.1 release of the PQC-LEO project!

## Release Overview
Version 0.6.1 is a maintenance release focused on dependency updates and improved benchmark result processing.

It upgrades OpenSSL to version 4.0.3 and the OQS-Provider dependency to version 0.12.0, replacing the interim commit used in v0.6.0. As part of the improvement to benchmark result processing, the existing `inf` handling now covers classical TLS handshake results.

It also fixes an incorrect OpenSSL path in the TLS speed energy testing script, allowing it to use the project's local OpenSSL build. This fix was included in [PR 137](https://github.com/crt26/PQC-LEO/pull/137) as part of the OQS-Provider upgrade.

## Change Log
- Upgrade OpenSSL dependency to 4.0.3 in [PR 136](https://github.com/crt26/PQC-LEO/pull/136)
- Upgrade OQS-Provider Dependency to 0.12.0 in [PR 137](https://github.com/crt26/PQC-LEO/pull/137)
- Add inf result handling for classical TLS handshake testing in [PR 139](https://github.com/crt26/PQC-LEO/pull/139)

**Full Changelog**: https://github.com/crt26/PQC-LEO/compare/v0.6.0...v0.6.1

## Important Notes
- PQC-LEO currently only supports Debian-based operating systems.

- PQC energy benchmarking remains in the early stages of development. Although it is fully functional, energy meter support is limited and fan speed control (useful to help maintain a consistent system energy usage baseline) must be adjusted manually. Detailed instructions have been included on how to add internal API support for additional energy meters in the [Integrating New Energy Meters](docs/developer_information/energy_collector_APIs/integrating_new_energy_meters.md) documentation file.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be found in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.

- The project dependencies used in PQC-LEO v0.6.1 include a known issue where certain PQC, Hybrid-PQC, and classical algorithm combinations may still produce `inf` values for "Connections Per User Second" in TLS handshake tests with short testing windows. Test durations of 5 seconds or greater are recommended to reduce the likelihood of this occurring. See the [TLS Handshake Inf Result Handling](./docs/performance_results/tls_handshake_inf_result_handling.md) documentation.

## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)
