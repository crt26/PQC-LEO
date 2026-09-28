# PQC-LEO <!-- omit from toc -->

## Project Description <!-- omit from toc -->
PQC-LEO (PQC-Library Evaluation Operator) provides an automated and comprehensive evaluation framework for benchmarking Post-Quantum Cryptography (PQC) algorithms. It is designed for researchers and developers looking to evaluate the feasibility of integrating PQC into their environments. The framework streamlines the setup and testing of PQC implementations, enabling the collection of computational and networking performance metrics across x86 and ARM systems through a suite of dedicated automation scripts. Furthermore, the framework supports energy usage testing of PQC algorithms using supported energy meters, providing insights into the energy efficiency of these algorithms in real-world scenarios.

PQC implementations are sourced from multiple libraries, including algorithms natively supported in OpenSSL 4.0.1 and those available from the [Open Quantum Safe (OQS)](https://openquantumsafe.org/) project's `Liboqs` and `OQS-Provider` libraries. PQC-LEO supports automated TLS handshake testing over loopback or physical networks, TLS handshake transmission cost testing, and energy measurement tools that capture power usage during both computational and TLS benchmarks. Performance and energy results are output as raw CSV and text files and automatically parsed into structured metrics and averages, while transmission cost tests produce structured CSV files directly.

Future versions of the project aim to support additional PQC libraries, further expanding the scope of supported benchmarking.

### Supported Automation Functionality <!-- omit from toc -->
The project provides automation for:

- Verifying and installing required system packages and Python PIP dependencies.

- Compiling and configuring the OpenSSL, OQS, and ARM PMU dependency libraries.

- Collecting PQC computational performance data, including CPU and peak memory usage metrics, using the Liboqs library.

- Gathering networking performance data for PQC schemes integrated into the TLS 1.3 protocol using the PQC support available natively in OpenSSL 4.0.1 and via the OQS-Provider.

- Measuring the transmission cost of one-way and mutually authenticated TLS 1.3 handshakes across PQC, Hybrid-PQC, and classical configurations.

- Coordinated PQC TLS handshake tests run over the loopback interface or across physical networks between a server and client device.

- Measuring energy consumption for computational and TLS benchmarks using supported energy meters and collection environments.

- Automatic or manual parsing of raw performance data, including calculating averages across multiple test runs.

### Project Development <!-- omit from toc -->
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-LEO Project Page](https://github.com/users/crt26/projects/2)

### Citation and Academic Use <!-- omit from toc -->
If using PQC-LEO within academic research or publication, please cite the following paper which formally introduces the framework:

```
@inproceedings{turino2025pqc,
  title={PQC-LEO: An Evaluation Framework for Post-Quantum Cryptographic Algorithms},
  author={Turino, Callum and Buchanan, William J and Lo, Owen and Th{\"u}mmler, Christoph},
  booktitle={2025 IEEE 7th International Conference on Trust, Privacy and Security in Intelligent Systems, and Applications (TPS-ISA)},
  pages={237--247},
  year={2025},
  organization={IEEE}
}
```

Paper DOI: [10.1109/TPS-ISA67132.2025.00033](https://doi.org/10.1109/TPS-ISA67132.2025.00033)

## Contents <!-- omit from toc -->
- [Supported Hardware and Software](#supported-hardware-and-software)
- [Supported Cryptographic Algorithms](#supported-cryptographic-algorithms)
- [Supported Environments for PQC Energy Usage Testing](#supported-environments-for-pqc-energy-usage-testing)
- [Installation Instructions](#installation-instructions)
  - [Cloning the Repository](#cloning-the-repository)
  - [Choosing Installation Mode](#choosing-installation-mode)
  - [Ensuring Root Dir Path Marker is Present](#ensuring-root-dir-path-marker-is-present)
  - [Optional Setup Flags](#optional-setup-flags)
- [Automated Testing Tools](#automated-testing-tools)
  - [Computational Performance Testing](#computational-performance-testing)
  - [TLS Performance Testing](#tls-performance-testing)
  - [TLS Handshake Transmission Cost Testing](#tls-handshake-transmission-cost-testing)
  - [PQC Energy Usage Testing](#pqc-energy-usage-testing)
  - [Testing Output Files](#testing-output-files)
- [Parsing Test Results](#parsing-test-results)
- [Additional Documentation](#additional-documentation)
- [Licence](#licence)
- [Acknowledgements](#acknowledgements)

## Supported Hardware and Software

### Compatible Hardware and Operating Systems <!-- omit from toc -->
The automated testing tool is currently only supported in the following environments:

- x86 Linux Machines using a Debian-based operating system
- ARM Linux devices using a 64-bit Debian-based Operating System

### Tested Cryptographic Dependency Libraries <!-- omit from toc -->
This version of the repository has been fully tested with the following library versions:

- Liboqs Version: 0.16.0

- OQS-Provider Version 0.11.0+

- OpenSSL Version 4.0.1

By default, this repository is configured to use the **last tested versions** of the OQS libraries. This helps ensure that all automation scripts operate reliably with known working versions. The listed OpenSSL version remains fixed at 4.0.1 to maintain compatibility with the OQS-Provider library and the project's performance testing tools.

While this setup maximises reliability, users who need access to more recent updates may configure the setup process accordingly. However, please note that the OQS libraries are still in active development, and upstream changes may occasionally break compatibility with this project’s automation scripts. This is detailed further in the [Installation Instructions](#installation-instructions) section.

If any such issues arise, please report them to this repository’s GitHub Issues page so they can be addressed promptly. Instructions for modifying the library versions used by the benchmarking suite are provided in the Installation Instructions section.

For information on the specific project dependencies libraries used by PQC-LEO, see the [Project Dependencies](./docs/developer_information/project_dependencies.md) documentation.

## Supported Cryptographic Algorithms
For further information on the classical and PQC algorithms this project provides support for, including information on any exclusions, please refer to the following documentation:

[Supported Algorithms](docs/supported_algorithms.md)

## Supported Environments for PQC Energy Usage Testing
The [energy collector tools](./docs/developer_information/project_tools.md) included with PQC-LEO provide mechanisms for measuring the energy usage of PQC algorithms across different environments. PQC-LEO also includes automated Bash scripts that use these tools to evaluate the energy usage of PQC computational operations and TLS performance. However, the energy collector tools can also be used independently of the provided scripts, allowing energy usage testing to be adapted for other environments and use cases.

Energy usage testing is currently supported only on Linux-based systems and for a limited number of energy meter devices. For more information on supported devices and collection tools, see the [Supported Energy Meters](./docs/energy_meter_guides/energy_meter_support.md) documentation.

To support future expansion, the energy collector tools have been designed with modular control signal and data collection mechanisms. This allows additional energy meters and collection techniques to be integrated more easily, both within the automated testing scripts provided by PQC-LEO and in external testing workflows. Please refer to the relevant [Integrating New Energy Meters](./docs/developer_information/energy_collector_APIs/integrating_new_energy_meters.md) documentation for guidance on extending energy meter support.

The energy usage testing components of PQC-LEO are still in the early stages of development. Support for a wider range of energy collection methods and techniques will continue to be expanded and improved as the project progresses.

## Installation Instructions
The standard setup process uses the last tested commits of the project's dependency libraries to ensure compatibility with this project's automation tools. The setup script performs system detection, installs all required components, and supports multiple installation modes depending on the desired testing configuration.

While the default configuration prioritises stability, users may optionally configure the setup to pull newer versions of the OQS libraries. This can be useful for testing upstream changes or recent algorithm updates. For more advanced configuration options, see the [Optional Setup Flags](#optional-setup-flags) section.

The following instructions describe the standard setup process, which is the default and recommended option.

### Cloning the Repository
Clone the current stable version:

```
git clone https://github.com/crt26/PQC-LEO.git
```

Move into the cloned repository directory and execute the setup script:

```
cd PQC-LEO
./setup.sh
```

You may need to change the permissions of the setup script; if that is the case, this can be done using the following commands:

```
chmod +x ./setup.sh
```

### Choosing Installation Mode
When executing the setup script, you will be prompted to select one of the following installation options:

1. **Computational Performance Testing Only** - Installs components for standalone performance benchmarking (CPU and memory).

2. **Full Install** - Installs all components for computational performance, TLS performance, and TLS handshake transmission cost testing.

3. **TLS Testing Libraries Only** - Installs the components required for TLS performance and TLS handshake transmission cost testing. (**Requires Option 1 has already been completed**).

4. **Energy Collector Machine Setup** - Installs only the energy collector tools and its dependencies for use on the energy usage collection device. This device is used to poll the energy meter and collect energy usage data during testing and is separate from the main testing machines.

Installation options 1–3 also require the PQC-LEO [OpenSSL 4.0.1](https://github.com/openssl/openssl/releases/tag/openssl-4.0.1) build in the repository’s `lib` directory to support the OQS libraries. This is built automatically during setup and managed separately from the system OpenSSL installation. The OpenSSL installation used for the energy measurement tools is selected independently.

For installation options 1–3, the setup script prompts you to choose whether to install **energy measurement tools**; option 4 always installs the collector tools. When energy tools are installed, the setup checks whether the system OpenSSL installation is compatible. If so, you can choose between the system OpenSSL installation and the PQC-LEO build. If not, the PQC-LEO build must be used. See [OpenSSL Compatibility for Energy Tools](docs/developer_information/project_dependencies.md#openssl-compatibility-for-energy-tools) for compatibility requirements and manual runtime configuration.

Some energy-testing features, such as UART communication for control signalling, require additional configuration after setup. Refer to the relevant internal and external documentation for details.

If the TLS testing libraries are installed (Options 2 or 3), you will be prompted with the following additional setup options:

- **Enable all disabled OQS-Provider algorithms supported by PQC-LEO** – Enables OQS-Provider algorithms supported by PQC-LEO that are disabled by default. This ensures the full range of supported algorithms can be tested in the TLS performance benchmarking **†**.

- **Enable KEM encoders** – Adds support for OpenSSL’s optional KEM encoder functionality. This option is **automatically enabled** if energy measurement tools are configured to be installed as the KEM encoders are required for TLS operations energy usage testing.

Once all the relevant options have been selected, the setup script will download, configure and build each library. It will also tailor the builds for your system architecture by applying appropriate build flags.

If issues occur during installation that prevent the project from functioning correctly, it is recommended that a clean installation is performed. This can be done by running the `cleaner.sh` utility script and selecting **Uninstall Libraries Only**, followed by **Uninstall all Libraries**. Existing benchmarking results will be preserved when using these options. Once this has completed, rerun the `setup.sh` script and select the desired installation option. Please note that Option 3 requires an existing computational installation; for a fresh installation with TLS support, select Option 2.

> † Enabling all disabled OQS-Provider algorithms may cause the OpenSSL speed tool to fail due to internal limits in its source code. The setup script attempts to patch this automatically, but you can configure this process manually. Please refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) for further details.

### Ensuring Root Dir Path Marker is Present
A hidden file named `.pqc_leo_dir_marker.tmp` is created in the project's root directory during setup. Automation scripts use this marker to reliably identify the root path, which is essential for their correct operation.

When running the setup script, it is vital that this is done from the root of the repository so that this file is placed correctly. 

Do **not** delete or rename this file while the project is in a configured state. It will be automatically removed when uninstalling all libraries using the `cleaner.sh` utility script. If the file is removed manually, it can be regenerated by rerunning the setup script or creating it manually.

To verify the file exists, use:

```
ls -la
```

To manually recreate the file, run the following command from the project's root directory:

```
touch .pqc_leo_dir_marker.tmp
```

### Optional Setup Flags
For advanced setup options, including:
- Pulling the latest version of the OQS libraries rather than the default tested versions
- Custom OpenSSL `speed.c` limits
- Enabling Liboqs memory optimised implementations
 
Please refer to the [Advanced Setup Configuration Guide](docs/advanced_setup_configuration.md).

## Automated Testing Tools
The repository provides four categories of automated PQC benchmarking:

- **Computational Performance Testing** – Benchmarks the standalone performance of PQC cryptographic operations, gathering data on CPU and peak memory usage.

- **TLS Performance Testing** – Benchmarks PQC, Hybrid-PQC, and classical TLS 1.3 handshake configurations and cryptographic operation performance.

- **TLS Handshake Transmission Cost Testing** – Measures the bytes sent and received during one-way and mutually authenticated TLS 1.3 handshakes.

- **PQC Energy Usage Testing** – Benchmarks the energy consumption of PQC algorithms during computational and TLS performance testing using supported energy meters.

The testing tools are located in the `scripts/test_scripts` directory and are fully automated. The tools support assigning custom machine-IDs to the gathered results to make it easy to compare performance on differing systems.

### Computational Performance Testing
This tool benchmarks CPU and peak memory usage for various PQC algorithms supported by the Liboqs library. It produces detailed performance metrics for each tested algorithm.

For detailed usage instructions, please refer to:

[Automated Computational Performance Testing Instructions](docs/testing_tools_usage/computational_performance_testing.md)

> **Notice:** Memory profiling for Falcon algorithm variants is currently non-functional on **ARM** systems due to issues with the scheme and the Valgrind Massif tool. Please see the [bug report](https://github.com/open-quantum-safe/liboqs/issues/1761) for details. Testing and parsing remain fully functional for all other algorithms.

### TLS Performance Testing
This tool benchmarks the performance of PQC, Hybrid-PQC, and classical algorithms when used in the TLS 1.3 protocol. It utilises the PQC implementations natively available in OpenSSL 4.0.1 and those added via the OQS-Provider.

It conducts two types of testing:

- **TLS handshake performance testing** – Measures the performance of PQC, Hybrid-PQC, and classical algorithms during TLS 1.3 handshakes.

- **Cryptographic operation benchmarking** – Measures the CPU performance of individual PQC/Hybrid-PQC digital signature and Key Encapsulation Mechanism (KEM) operations, together with classical digital signature and key-exchange operations, when integrated within OpenSSL.

Testing can be performed on a single machine or across two machines connected via a physical/virtual network. While the multi-machine setup involves additional configuration, it is fully supported by the automation tools.

For detailed usage instructions, please refer to:

[Automated TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md)

>**Notice:** The versions of project dependencies used in PQC-LEO version 0.5.0 contains a known issue where certain signature/KEM combinations may produce values of `inf` for "Connections Per User Second" results in TLS handshake testing when using smaller testing windows. Please refer to the [TLS Handshake Inf Result Handling](./docs/performance_results/tls_handshake_inf_result_handling.md) documentation for further information.

### TLS Handshake Transmission Cost Testing
This tool measures the amount of data exchanged during TLS 1.3 handshakes using PQC, Hybrid-PQC, and classical algorithm configurations. It tests every supported signing algorithm and KEM pairing for PQC and Hybrid-PQC, and every supported signing algorithm, key exchange group, and ciphersuite combination for classical TLS. Each configuration is tested using both one-way and mutual authentication and the bytes sent, bytes received, and total bytes during the handshake are recorded from the client's perspective.

The test runs locally over the loopback interface and writes final CSV results directly to the `results` directory.

For detailed usage instructions, please refer to:

[TLS Handshake Transmission Cost Testing Instructions](docs/testing_tools_usage/tls_handshake_transmission_cost_testing.md)

### PQC Energy Usage Testing
This tool benchmarks the energy consumption of supported cryptographic algorithms during computational and TLS testing, including PQC, Hybrid-PQC, and classical configurations where applicable. It provides tools and automation scripts to collect energy usage metrics using supported energy meters and a collection device. It supports automation for the following categories of energy usage testing:

- Computational Performance Energy Testing
- TLS Handshake Energy Testing
- TLS Operations Energy Testing

This component of the PQC-LEO framework includes two core elements, the automated energy usage testing scripts and the [energy collector tools](./docs/developer_information/project_tools.md). The energy collector tools provide a flexible way in which to orchestrate testing between collection and testing devices using serial or network communications and provide a modular way to integrate support for different energy meters. The automated energy usage testing scripts provide an easy to use interface for utilising the energy collector tools.

Current support for energy meter devices is limited, but the framework is designed to allow the integration of additional meters in the future in a simple as possible way.

For detailed usage instructions, please refer to:

[Energy Usage Testing Instructions](docs/testing_tools_usage/pqc_energy_usage_testing.md)

>**Notice:** Certain OpenSSL Hybrid-PQC KEM algorithms that are supported for normal TLS speed performance testing are not supported for TLS operations energy usage testing due to limitations in encoder support. Please refer to OpenSSL algorithms section of the [Supported Algorithms](docs/supported_algorithms.md#openssl-algorithms) documentation for further details.

### Testing Output Files
After testing has completed, raw and parsed results are stored in the generated `test_data/` directory:

**Unparsed Results:** `test_data/up_results/`

**Parsed Results:** `test_data/results/`

TLS handshake transmission cost results are written directly under `test_data/results/` and do not have a corresponding unparsed result directory.

## Parsing Test Results
By default, performance and energy test results are automatically parsed at the end of their testing scripts. The TLS handshake transmission cost tool instead writes structured CSV files directly and does not use the automated parsing process.

Parsed results will be stored in the following directories, depending on which testing was performed:

- `test_data/results/computational_performance/machine_x`
- `test_data/results/tls_performance/machine_x`
- `test_data/results/tls_handshake_bytes/machine_x`
- `test_data/results/energy_test_results/[test_type]/machine_x`

`machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be used.

For energy usage testing results, `test_type` refers to one of the following testing categories based on the type of results that were parsed.

If needed, automatic parsing can be disabled when calling the testing scripts by passing a flag to the testing script. This then facilitates the manual calling of the Python parsing scripts.

For complete details on parsing functionality and a breakdown of the collected performance metrics, refer to the following documentation:

- [Parsing Performance Results Usage Guide](docs/performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](docs/performance_results/performance_metrics_guide.md)

## Additional Documentation

### Internal Project Documentation <!-- omit from toc -->
Links below provide access to the various internal project documentation. However, the majority of these documents can be found in the `docs` directory at the project's root.

| **Category**                                 | **Documentation**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|----------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Testing Tools Usage                          | - [Automated Computational Performance Testing](docs/testing_tools_usage/computational_performance_testing.md) <br> - [Automated TLS Performance Testing](docs/testing_tools_usage/tls_performance_testing.md) <br> - [TLS Handshake Transmission Cost Testing](docs/testing_tools_usage/tls_handshake_transmission_cost_testing.md) <br> - [PQC Energy Usage Testing](docs/testing_tools_usage/pqc_energy_usage_testing.md) <br> - [Computational Energy Usage Testing](docs/testing_tools_usage/energy_usage_testing_guides/comp_energy_usage_testing.md) <br> - [TLS Handshake Energy Usage Testing](docs/testing_tools_usage/energy_usage_testing_guides/tls_handshake_energy_usage_testing.md) <br> - [TLS Operations Energy Usage Testing](docs/testing_tools_usage/energy_usage_testing_guides/tls_operations_energy_usage_testing.md) |
| Setup & Configuration                        | - [Advanced Setup Configuration](docs/advanced_setup_configuration.md) <br> - [Supported Algorithms](docs/supported_algorithms.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Project Dependencies & Developer Information | - [Project Dependencies](./docs/developer_information/project_dependencies.md) <br> - [Project Scripts](docs/developer_information/project_scripts.md) <br> - [Project Tools](docs/developer_information/project_tools.md) <br> - [Repository Structure](docs/developer_information/repository_directory_structure.md) <br> - [Energy Collector Controller API Guide](docs/developer_information/energy_collector_APIs/controller_api_guide.md) <br> - [Energy Collector Meter API Guide](docs/developer_information/energy_collector_APIs/meter_api_guide.md) <br> - [Integrating New Energy Meters](docs/developer_information/energy_collector_APIs/integrating_new_energy_meters.md)                                                                                                                                            |
| Project Tools Guides                         | - [Computational Energy Tester Usage Guide](docs/project_tools_guides/comp_energy_tester_usage_guide.md) <br> - [Energy Collector Usage Guide](docs/project_tools_guides/energy_collector_usage_guide.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Energy Meter Guides                          | - [Energy Meter Support](docs/energy_meter_guides/energy_meter_support.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Performance Results                          | - [Parsing Performance Results Usage Guide](docs/performance_results/parsing_scripts_usage_guide.md) <br> - [Performance Metrics Guide](docs/performance_results/performance_metrics_guide.md) <br> - [TLS Handshake Inf Result Handling](docs/performance_results/tls_handshake_inf_result_handling.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Other Resources                              | - [Project Disclaimer](./DISCLAIMER.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

### Project Wiki Page <!-- omit from toc -->
The information provided in the internal documentation is also available through the project's GitHub Wiki:

[PQC-LEO Wiki](https://github.com/crt26/PQC-LEO/wiki)

### Helpful External Documentation Links <!-- omit from toc -->
- [Liboqs Webpage](https://openquantumsafe.org/liboqs/)
- [Liboqs GitHub Page](https://github.com/open-quantum-safe/liboqs)
- [OQS-Provider Webpage](https://openquantumsafe.org/applications/tls.html#oqs-openssl-provider)
- [OQS-Provider GitHub Page](https://github.com/open-quantum-safe/oqs-provider)
- [Latest Liboqs Release Notes](https://github.com/open-quantum-safe/liboqs/blob/main/RELEASE.md)
- [Latest OQS-Provider Release Notes](https://github.com/open-quantum-safe/oqs-provider/blob/main/RELEASE.md)
- [OpenSSL(4.0.1) Documentation](https://docs.openssl.org/4.0/)
- [TLS 1.3 RFC 8446](https://www.rfc-editor.org/rfc/rfc8446)

## Licence
This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.

## Acknowledgements
This project depends on the following third-party software and libraries:

1. **[Liboqs](https://github.com/open-quantum-safe/liboqs)** – Used to provide standalone implementations of post-quantum key encapsulation mechanisms (KEMs) and digital signature algorithms for computational performance testing. This project includes modified versions of the `test_kem_mem.c` and `test_sig_mem.c` files in order to collect detailed memory usage metrics during benchmarking with minimal terminal output. These modifications remain under the original MIT License, which is noted at the top of each modified file.

2. **[OQS-Provider](https://github.com/open-quantum-safe/oqs-provider)** – Used to integrate post-quantum algorithms from `Liboqs` into OpenSSL via the provider interface, enabling TLS-based performance testing. Modifications include dynamically altering the `generate.yml` template to optionally enable all signature algorithms that are disabled by default. The provider is built locally and dynamically linked into OpenSSL. It is licensed under the MIT License.

3. **[OpenSSL](https://github.com/openssl/openssl)** – Used as the core cryptographic library for TLS testing and benchmarking. This project applies runtime modifications during the build process to increase the hardcoded algorithm limits in `speed.c` (`MAX_KEM_NUM` and `MAX_SIG_NUM`) to support benchmarking of a broader algorithm set, and to append configuration directives to `openssl.cnf` to register and activate the `oqsprovider`. OpenSSL is licensed under the Apache License 2.0.

4. **[pqax](https://github.com/mupq/pqax)** – Used to enable access to the ARM Performance Monitor Unit (PMU) on ARM-based systems such as Raspberry Pi. This allows precise benchmarking of CPU cycles. No modifications are made to the original source code. Pqax is licensed under the Creative Commons Zero v1.0 Universal (CC0) license, placing it in the public domain.