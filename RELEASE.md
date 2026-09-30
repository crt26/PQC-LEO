# PQC-LEO v0.6.0 Release
Welcome to the version 0.6.0 release of the PQC-LEO project!

## Release Overview
Version 0.6.0 is a major feature release that expands PQC-LEO's benchmarking capabilities across computational, TLS, energy, and transmission testing.

This release introduces PQC energy usage benchmarking, TLS 1.3 handshake transmission cost benchmarking, and expanded classical algorithm support.

It also updates several core cryptographic dependencies, including Liboqs, OQS-Provider, and OpenSSL, while improving TLS testing reliability, command parsing, energy-tool configuration, and setup validation.

## Change Log
- Fix shutil.rmtree silently deleting entire results parent directory by @MarkAtwood in [PR 100](https://github.com/crt26/PQC-LEO/pull/100)
- Add support for PQC energy usage benchmarking by @crt26 in [PR 115](https://github.com/crt26/PQC-LEO/pull/115)
- Add changes to fix PQC performance testing command parsing by @crt26 in [PR 116](https://github.com/crt26/PQC-LEO/pull/116)
- Fix TLS testing custom control sleep time validation failing by @crt26 in [PR 117](https://github.com/crt26/PQC-LEO/pull/117)
- Fix TLS handshake server handling of failed control signals by @crt26 in [PR 118](https://github.com/crt26/PQC-LEO/pull/118)
- Update pinned Liboqs dependency to version 0.16.0 by @crt26 in [PR 119](https://github.com/crt26/PQC-LEO/pull/119)
- Update pinned OQS-Provider dependency to version 0.11.0+ by @crt26 in [PR 120](https://github.com/crt26/PQC-LEO/pull/120)
- Retire legacy HQC enablement handler and use standard HQC support by @crt26 in [PR 121](https://github.com/crt26/PQC-LEO/pull/121)
- Upgrade OpenSSL dependency to 4.0.1 by @crt26 in [PR 122](https://github.com/crt26/PQC-LEO/pull/122)
- Add support for TLS 1.3 handshake transmission cost benchmarking by @crt26 in [PR 123](https://github.com/crt26/PQC-LEO/pull/123)
- Expand classical algorithm benchmarking across TLS, speed, energy, and transmission testing by @crt26 in [PR 124](https://github.com/crt26/PQC-LEO/pull/124)
- Rename TLS speed energy testing to TLS operations energy testing by @crt26 in [PR 125](https://github.com/crt26/PQC-LEO/pull/125)
- Add shared OpenSSL selection and compatibility handling for energy tools by @crt26 in [PR 126](https://github.com/crt26/PQC-LEO/pull/126)
- Upgrade OpenSSL dependency to 4.0.2 by @crt26 in [PR 127](https://github.com/crt26/PQC-LEO/pull/127)
- Tidy repository files and fix consistency issues by @crt26 in [PR 128](https://github.com/crt26/PQC-LEO/pull/128)
- Fix OpenSSL compatibility check running before libssl-dev installation by @crt26 in [PR 130](https://github.com/crt26/PQC-LEO/pull/130)

**Full Changelog**: https://github.com/crt26/PQC-LEO/compare/v0.5.1...v0.6.0

**New Contributors:**
- @MarkAtwood made their first contribution in [PR 100](https://github.com/crt26/PQC-LEO/pull/100)

## Important Notes
- PQC energy benchmarking has been introduced in this release. However, it is still in the early stages of its development. Although it is fully functional, energy meter support is limited and fan speed control (useful to help maintain consistent system energy usage baseline) must be adjusted manually. Detailed instructions have been included on how to add internal API support for additional energy meters in the [Integrating New Energy Meters](docs/developer_information/energy_collector_APIs/integrating_new_energy_meters.md) documentation file.

- The pinned OQS-Provider dependency is currently set to a commit from `main` between the 0.11.0 and 0.12.0 releases. This is because Liboqs v0.16.0 requires a compatible OQS-Provider version that is not yet available as a full release. The pinned OQS-Provider version has been tested and confirmed to work with Liboqs v0.16.0. Once the next OQS-Provider release is available, the pinned dependency will be updated to the full release in PQC-LEO v0.6.1.

- PQC-LEO currently supports Debian-based operating systems.

- If issues still occur with the automated TLS performance test control signalling, information on increasing the signal sleep delay can be found in the **Advanced Testing Customisation** section of the [TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md) documentation file.

- The project dependencies used in PQC-LEO v0.6.0 include a known issue where certain signature/KEM combinations may produce `inf` values for "Connections Per User Second" in TLS handshake tests with small testing windows. See the [TLS Handshake Inf Result Handling](./docs/performance_results/tls_handshake_inf_result_handling.md) documentation.

## Future Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)
