# PQC Evaluation Tools <!-- omit from toc -->

## Notice: <!-- omit from toc -->
This is the **development branch**; it may not be in a fully functioning state, and the documentation may still need to be updated. The checkboxes below indicate whether the current development version is in a basic functioning state and if the documentation is accurate for its current functionality. Regardless, please keep this in mind and use the main branch if possible. Thank you.

- [x] Functioning State
- [x] Up-to-date documentation

### Main Development Branch Task Tracking
For full details on the project's development and the current development task lists, please refer to the repository's Github Projects Page here:

[PQC-Evaluation-Tools Project Page](https://github.com/users/crt26/projects/2)

## Repository Overview <!-- omit from toc -->

### Project Description
This repository provides an automated and comprehensive evaluation framework for benchmarking Post-Quantum Cryptography (PQC) algorithms. It is designed for researchers and developers looking to evaluate the feasibility of integrating PQC into their environments. The framework streamlines the setup and testing of PQC implementations, enabling the collection of computational and networking performance metrics across x86 and ARM systems through a suite of dedicated automation scripts.

PQC implementations are sourced from multiple libraries, including algorithms natively supported in OpenSSL 3.5.0 and those available from the [Open Quantum Safe (OQS)](https://openquantumsafe.org/) project's `Liboqs` and `OQS-Provider` libraries. The framework also provides automated mechanisms for testing PQC TLS handshake performance across physical or virtual networks, providing valuable insight into real-world environment testing. Results are outputted as raw CSV files that are automatically processed using the provided Python parsing scripts to provide detailed metrics and averages ready for analysis.

Future versions of the project aim to support additional PQC libraries, further expanding the scope of supported benchmarking.

### Supported Automation Functionality
The project provides automation for:

- Verifying and installing required system packages and Python PIP dependencies.

- Compiling and configuring the OpenSSL, OQS, and ARM PMU dependency libraries.

- Collecting PQC computational performance data, including CPU and memory usage metrics, using the Liboqs library.

- Gathering networking performance data for PQC schemes integrated into the TLS 1.3 protocol using the PQC support available natively in OpenSSL 3.5.0 and via the OQS-Provider.

- Coordinated PQC TLS handshake tests run over the loopback interface or across physical networks between a server and client device.

- Automatic or manual parsing of raw performance data, including calculating averages across multiple test runs.

### Project Development
For details on the project's development and upcoming features, see the project's GitHub Projects page:

[PQC-Evaluation-Tools Project Page](https://github.com/users/crt26/projects/2)

## Contents <!-- omit from toc -->
- [Supported Hardware and Software](#supported-hardware-and-software)
- [Supported Cryptographic Algorithms](#supported-cryptographic-algorithms)
- [Installation Instructions](#installation-instructions)
  - [Cloning the Repository](#cloning-the-repository)
  - [Choosing Installation Mode](#choosing-installation-mode)
  - [Ensuring Root Dir Path Marker is Present](#ensuring-root-dir-path-marker-is-present)
  - [Optional Setup Flags](#optional-setup-flags)
- [Automated Testing Tools](#automated-testing-tools)
  - [Computational Performance Testing](#computational-performance-testing)
  - [TLS Performance Testing](#tls-performance-testing)
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

- Liboqs Version: Post-0.13.0 commit **†**

- OQS-Provider Version 0.9.0

- OpenSSL Version 3.5.0

By default, this repository is configured to use the **last tested versions** of the OQS libraries. This helps ensure that all automation scripts operate reliably with known working versions. The listed OpenSSL version remains fixed at 3.5.0 to maintain compatibility with the OQS-Provider and the project's performance testing tools. 

While this setup maximises reliability, users who need access to more recent updates may configure the setup process accordingly. However, please note that the OQS libraries are still in active development, and upstream changes may occasionally break compatibility with this project’s automation scripts. This is detailed further in the [Installation Instructions](#installation-instructions) section.

If any such issues arise, please report them to this repository’s GitHub Issues page so they can be addressed promptly. Instructions for modifying the library versions used by the benchmarking suite are provided in the Installation Instructions section.

**†** For information on the specific commits used for the last tested versions of the dependency libraries, see the [Project Dependencies](./docs/developer_information/project_dependencies.md) documentation.

## Supported Cryptographic Algorithms
For further information on the classical and PQC algorithms this project provides support for, including information on any exclusions, please refer to the following documentation:

[Supported Algorithms](docs/supported_algorithms.md)

**Notice:** The HQC KEM algorithms are disabled by default in recent versions of both Liboqs and the OQS-Provider, due to their current implementations not conforming to the latest specification, which includes important security fixes. For benchmarking purposes, the setup process includes an optional flag to enable HQC in these libraries, accompanied by a user confirmation prompt and warning. Enabling HQC is done at the user's own discretion, and this project assumes no responsibility for its use. For instructions on enabling HQC, see the [Advanced Setup Configuration Guide](docs/advanced_setup_configuration.md), and refer to the [Disclaimer Document](./DISCLAIMER.md) for more information on this issue.

## Installation Instructions
The standard setup process uses the last tested commits of the project's dependency libraries to ensure compatibility with this project's automation tools. The setup script performs system detection, installs all required components, and supports multiple installation modes depending on the desired testing configuration.

While the default configuration prioritises stability, users may optionally configure the setup to pull newer versions of the OQS libraries. This can be useful for testing upstream changes or recent algorithm updates. For more advanced configuration options, see the [Optional Setup Flags](#optional-setup-flags) section.

The following instructions describe the standard setup process, which is the default and recommended option.

### Cloning the Repository
Clone the current stable version:

```
git clone https://github.com/crt26/pqc-evaluation-tools.git
```

Move into the cloned repository directory and execute the setup script:

```
cd pqc-evaluation-tools
./setup.sh
```

You may need to change the permissions of the setup script; if that is the case, this can be done using the following commands:

```
chmod +x ./setup.sh
```

### Choosing Installation Mode
When executing the setup script, you will be prompted to select one of the following installation options:

1. **Computational Performance Testing Only** - Installs components for standalone performance benchmarking (CPU and memory).

2. **Full Install** - Installs all components for both computational and TLS performance testing.

3. **TLS Testing Libraries Only** - Installs only the TLS benchmarking components. (**Requires Option 1 has already been completed**).

The setup script will also build [OpenSSL 3.5.0](https://github.com/openssl/openssl/releases/tag/openssl-3.5.0) inside the repository’s `lib` directory. This version is required to support the OQS libraries and is built separately from the system’s default OpenSSL installation. It will not interfere with system-level binaries.

If the TLS testing libraries are installed (Options 2 or 3), you will be prompted with the following additional setup options:

- **Enable all disabled signature algorithms** – Includes all digital signature algorithms in the OQS-Provider library that are disabled by default. This ensures the full range of supported algorithms can be tested in the TLS performance testing **†**.

- **Enable KEM encoders** – Adds support for OpenSSL’s optional KEM encoder functionality. The benchmarking suite does not currently use this feature, but it is available for developers who wish to experiment with it.

Once all the relevant options have been selected, the setup script will download, configure and build each library. It will also tailor the builds for your system architecture by applying appropriate build flags.

> † Enabling all signature algorithms may cause the OpenSSL speed tool to fail due to internal limits in its source code. The setup script attempts to patch this automatically, but you can configure this process manually. Please refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) for further details.

### Ensuring Root Dir Path Marker is Present
A hidden file named `.pqc_eval_dir_marker.tmp` is created in the project's root directory during setup. Automation scripts use this marker to reliably identify the root path, which is essential for their correct operation.

When running the setup script, it is vital that this is done from the root of the repository so that this file is placed correctly. 

Do **not** delete or rename this file while the project is in a configured state. It will be automatically removed when uninstalling all libraries using the `cleaner.sh` utility script. If the file is removed manually, it can be regenerated by rerunning the setup script or creating it manually.

To verify the file exists, use:

```
ls -la
```

To manually recreate the file, run the following command from the project's root directory:

```
touch .pqc_eval_dir_marker.tmp
```

### Optional Setup Flags
For advanced setup options, including:
- Pulling the latest version of the OQS libraries rather than the default tested versions
- Custom OpenSSL `speed.c` limits
- Enabling HQC algorithms in the OQS Libraries
 
Please refer to the [Advanced Setup Configuration Guide](docs/advanced_setup_configuration.md).

## Automated Testing Tools
The repository provides two categories of automated PQC benchmarking:

- **Computational Performance Testing** – Benchmarks the standalone performance of PQC cryptographic operations, gathering data on CPU and memory usage.

- **TLS Performance Testing** – Benchmarks PQC, Hybrid-PQC, and classic algorithms integrated into the TLS 1.3 protocol, including handshake and cryptographic operation performance.

The testing tools are located in the `scripts/test_scripts` directory and are fully automated. The tools support assigning custom machine-IDs to the gathered results to make it easy to compare performance on differing systems.

### Computational Performance Testing
This tool benchmarks CPU and memory usage for various PQC algorithms supported by the Liboqs library. It produces detailed performance metrics for each tested algorithm.

For detailed usage instructions, please refer to:

[Automated Computational Performance Testing Instructions](docs/testing_tools_usage/computational_performance_testing.md)

> **Notice:** Memory profiling for Falcon algorithm variants is currently non-functional on **ARM** systems due to issues with the scheme and the Valgrind Massif tool. Please see the [bug report](https://github.com/open-quantum-safe/liboqs/issues/1761) for details. Testing and parsing remain fully functional for all other algorithms.

### TLS Performance Testing
This tool benchmarks the performance of PQC, Hybrid-PQC, and classical algorithms when used in the TLS 1.3 protocol. It utilises the PQC implementations natively available in OpenSSL 3.5.0 and those added via the OQS-Provider.

It conducts two types of testing:

- **TLS handshake performance testing** – Measures the performance of PQC and Hybrid-PQC algorithms during TLS 1.3 handshakes.

- **Cryptographic operation benchmarking** – Measures the CPU performance of individual PQC/Hybrid-PQC digital signature and Key Encapsulation Mechanism (KEM) cryptographic operations when integrated within OpenSSL.

Testing can be performed on a single machine or across two machines connected via a physical/virtual network. While the multi-machine setup involves additional configuration, it is fully supported by the automation tools.

For detailed usage instructions, please refer to:

[Automated TLS Performance Testing Instructions](docs/testing_tools_usage/tls_performance_testing.md)

### Testing Output Files
After the testing has been completed, unparsed results and automatically parsed results will be stored in the generated `test_data/` directory:

**Unparsed Results:** `test_data/up_results/`

**Parsed Results:** `test_data/results/`

## Parsing Test Results
By default, test results are automatically parsed at the end of each testing script. This generates structured CSV output files based on the type of performance testing conducted.

Parsed results will be stored in the following directories, depending on which testing was performed:

- `test_data/results/computational_performance/machine_x`
- `test_data/results/tls_performance/machine_x`

Where `machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be set for the results.

If needed, automatic parsing can be disabled when calling the testing scripts by passing a flag to the testing script. This then facilitates the manual calling of the Python parsing scripts.

For complete details on parsing functionality and a breakdown of the collected performance metrics, refer to the following documentation:

- [Parsing Performance Results Usage Guide](docs/performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](docs/performance_results/performance_metrics_guide.md)

## Additional Documentation

### Internal Project Documentation <!-- omit from toc -->
Links below provide access to the various internal project documentation. However, the majority of these documents can be found in the `docs` directory at the project's root.

| **Category**                                     | **Documentation**                                                                                                                                                                                                                                  |
|--------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Testing Tools Usage**                          | - [Automated Computational Performance Testing](docs/testing_tools_usage/computational_performance_testing.md) <br> - [Automated TLS Performance Testing](docs/testing_tools_usage/tls_performance_testing.md)                                     |
| **Setup & Configuration**                        | - [Advanced Setup Configuration](docs/advanced_setup_configuration.md) <br> - [Supported Algorithms](docs/supported_algorithms.md)                                                                                                                 |
| **Project Dependencies & Developer Information** | - [Project Dependencies](./docs/developer_information/project_dependencies.md) <br> - [Project Scripts](docs/developer_information/project_scripts.md) <br> - [Repository Structure](docs/developer_information/repository_directory_structure.md) |
| **Performance Results**                          | - [Parsing Performance Results Usage Guide](docs/performance_results/parsing_scripts_usage_guide.md) <br> - [Performance Metrics Guide](docs/performance_results/performance_metrics_guide.md)                                                     |
| **Other Resources**                              | - [Project Disclaimer](./DISCLAIMER.md)                                                                                                                                                                                                            |

### Project Wiki Page <!-- omit from toc -->
The information provided in the internal documentation is also available through the project's GitHub Wiki:

[PQC-Evaluation-Tools Wiki](https://github.com/crt26/pqc-evaluation-tools/wiki)

### Helpful External Documentation Links <!-- omit from toc -->
- [Liboqs Webpage](https://openquantumsafe.org/liboqs/)
- [Liboqs GitHub Page](https://github.com/open-quantum-safe/liboqs)
- [OQS-Provider Webpage](https://openquantumsafe.org/applications/tls.html#oqs-openssl-provider)
- [OQS-Provider GitHub Page](https://github.com/open-quantum-safe/oqs-provider)
- [Latest Liboqs Release Notes](https://github.com/open-quantum-safe/liboqs/blob/main/RELEASE.md)
- [Latest OQS-Provider Release Notes](https://github.com/open-quantum-safe/oqs-provider/blob/main/RELEASE.md)
- [OpenSSL(3.5.0) Documentation](https://docs.openssl.org/3.5/)
- [TLS 1.3 RFC 8446](https://www.rfc-editor.org/rfc/rfc8446)

## Licence

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.

## Acknowledgements

This project depends on the following third-party software and libraries:

1. **[Liboqs](https://github.com/open-quantum-safe/liboqs)** – Used to provide standalone implementations of post-quantum key encapsulation mechanisms (KEMs) and digital signature algorithms for computational performance testing. This project includes modified versions of the `test_kem_mem.c` and `test_sig_mem.c` files in order to collect detailed memory usage metrics during benchmarking with minimal terminal output. These modifications remain under the original MIT License, which is noted at the top of each modified file.

2. **[OQS-Provider](https://github.com/open-quantum-safe/oqs-provider)** – Used to integrate post-quantum algorithms from `Liboqs` into OpenSSL via the provider interface, enabling TLS-based performance testing. Modifications include dynamically altering the `generate.yml` template to optionally enable all signature algorithms that are disabled by default. The provider is built locally and dynamically linked into OpenSSL. It is licensed under the MIT License.

3. **[OpenSSL](https://github.com/openssl/openssl)** – Used as the core cryptographic library for TLS testing and benchmarking. This project applies runtime modifications during the build process to increase the hardcoded algorithm limits in `speed.c` (`MAX_KEM_NUM` and `MAX_SIG_NUM`) to support benchmarking of a broader algorithm set, and to append configuration directives to `openssl.cnf` to register and activate the `oqsprovider`. OpenSSL is licensed under the Apache License 2.0.

4. **[pqax](https://github.com/mupq/pqax)** – Used to enable access to the ARM Performance Monitor Unit (PMU) on ARM-based systems such as Raspberry Pi. This allows precise benchmarking of CPU cycles. No modifications are made to the original source code. Pqax is licensed under the Creative Commons Zero v1.0 Universal (CC0) license, placing it in the public domain.

