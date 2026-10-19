# PQC-LEO v0.6.2 Release
Welcome to the version 0.6.2 release of the PQC-LEO project!

## Release Overview
Version 0.6.2 is a maintenance release which adds various enhancements and fixes.

It introduces configurable energy baseline measurement durations and increases the default baseline duration. It also removes the legacy TLS speed energy testing files which were accidentally included in the previous release.

Additionally, several fixes were made to the project's internal documentation as part of [PR 145](https://github.com/crt26/PQC-LEO/pull/145).

While preparing this release, several major issues were discovered in the [PQC-LEO Wiki](https://github.com/crt26/PQC-LEO/wiki), including broken links, missing images, and inconsistencies in the documentation. These issues have now been corrected and the Wiki has been updated to reflect the current state of the project. We apologise for any inconvenience this may have caused to users of the project.

## Change Log
- Add configurable baseline measurement duration to energy testing tools in [PR 144](https://github.com/crt26/PQC-LEO/pull/144)
- Remove legacy TLS speed energy test files in [PR 145](https://github.com/crt26/PQC-LEO/pull/145)

**Full Changelog**: https://github.com/crt26/PQC-LEO/compare/v0.6.1...v0.6.2

## Important Notes
- PQC-LEO currently only supports Debian-based operating systems.

- PQC energy benchmarking remains in the early stages of development. Although it is fully functional, energy meter support is limited and fan speed control (useful to help maintain a consistent system energy usage baseline) must be adjusted manually. Detailed instructions have been included on how to add internal API support for additional energy meters in the [Integrating New Energy Meters](docs/developer_information/energy_collector_APIs/integrating_new_energy_meters.md) documentation file.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be found in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.

- The project dependencies used in PQC-LEO v0.6.2 include a known issue where certain PQC, Hybrid-PQC, and classical algorithm combinations may still produce `inf` values for "Connections Per User Second" in TLS handshake tests with short testing windows. Test durations of 5 seconds or greater are recommended to reduce the likelihood of this occurring. See the [TLS Handshake Inf Result Handling](./docs/performance_results/tls_handshake_inf_result_handling.md) documentation.

- When regenerating algorithm lists manually, `get_algorithms.py` deletes all existing files in `test_data/alg_lists` before validating the selected option or checking its dependencies. This includes lists it may not regenerate, and also occurs for the algorithm-counting option `4` and invalid single arguments. Please back up any customised lists and select the option that covers all required testing categories. This issue will be patched in a future version.

## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)
