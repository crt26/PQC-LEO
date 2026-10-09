# Project Scripts Documentation <!-- omit from toc --> 

## Overview <!-- omit from toc --> 
This document provides additional reference information for the various scripts in the repository. This documentation is designed primarily for developers or those who wish to better understand the core functionality of the project's various scripts.

The project's scripts are grouped into the following categories:

- The utility scripts
- The automated computational performance testing scripts
- The automated TLS performance testing scripts
- The automated TLS handshake transmission cost testing script
- The automated energy usage testing scripts
- The performance data parsing scripts

It provides overviews of each script’s purpose, functionality, and any relevant parameters required when running the scripts manually.

### Contents <!-- omit from toc --> 
- [Project Utility Scripts](#project-utility-scripts)
  - [setup.sh](#setupsh)
  - [cleaner.sh](#cleanersh)
  - [configure\_openssl\_cnf.sh](#configure_openssl_cnfsh)
  - [get\_algorithms.py](#get_algorithmspy)
  - [oid\_handler.sh](#oid_handlersh)
  - [serial\_port\_selector.py](#serial_port_selectorpy)
  - [source\_code\_modifier.sh](#source_code_modifiersh)
  - [system\_state\_configurer.sh](#system_state_configurersh)
- [Automated Computational Performance Testing Scripts](#automated-computational-performance-testing-scripts)
  - [pqc\_performance\_test.sh](#pqc_performance_testsh)
- [Automated TLS Performance Testing Scripts](#automated-tls-performance-testing-scripts)
  - [pqc\_tls\_performance\_test.sh](#pqc_tls_performance_testsh)
  - [tls\_handshake\_test\_server.sh](#tls_handshake_test_serversh)
  - [tls\_handshake\_test\_client.sh](#tls_handshake_test_clientsh)
  - [tls\_speed\_test.sh](#tls_speed_testsh)
  - [tls\_generate\_keys.sh](#tls_generate_keyssh)
- [Automated TLS Handshake Transmission Cost Testing Scripts](#automated-tls-handshake-transmission-cost-testing-scripts)
  - [get\_pqc\_tls\_bytes.py](#get_pqc_tls_bytespy)
- [Automated Energy Usage Testing Scripts](#automated-energy-usage-testing-scripts)
  - [energy\_metric\_collector.sh](#energy_metric_collectorsh)
  - [pqc\_performance\_energy\_test.sh](#pqc_performance_energy_testsh)
  - [tls\_operations\_energy\_test.sh](#tls_operations_energy_testsh)
- [Performance Data Parsing Scripts](#performance-data-parsing-scripts)
  - [parse\_results.py](#parse_resultspy)
  - [performance\_data\_parse.py](#performance_data_parsepy)
  - [tls\_performance\_data\_parse.py](#tls_performance_data_parsepy)
  - [energy\_data\_parse.py](#energy_data_parsepy)
  - [results\_averager.py](#results_averagerpy)

## Project Utility Scripts
These utility scripts assist with development, testing, and environment setup. Most utility scripts are located in the `scripts/utility_scripts` directory, except `cleaner.sh` and `setup.sh`, which are placed in the project's root for convenience. The utility scripts are primarily designed to be called from the various automation scripts in the repository, but some can be called manually if needed.

The project utility scripts include the following:

- setup.sh
- cleaner.sh
- configure_openssl_cnf.sh
- get_algorithms.py
- oid_handler.sh
- serial_port_selector.py
- source_code_modifier.sh
- system_state_configurer.sh

### setup.sh
This script automates the full environment setup required to run the PQC benchmarking tools. It provides setup options for computational performance, TLS performance, TLS handshake transmission cost, and energy usage testing, and handles all necessary system configuration and dependency installation. Transmission cost testing uses the components installed by the TLS setup modes.

Key tasks performed include:

- Installing all required system and Python dependencies (e.g., OpenSSL dev packages, CMake, Valgrind)

- Downloading and compiling OpenSSL 4.0.3 when required for the selected setup

- Cloning and building the last-tested or latest versions of Liboqs and OQS-Provider

- Building and configuring the energy usage evaluation tools (`energy_collector` and `comp_energy_tester`) when energy testing is enabled

- Modifying OpenSSL’s speed.c to support extended algorithm counts when needed

- Enabling optional OQS-Provider features (e.g., KEM encoders, disabled signature algorithms)

- Generating algorithm lists used by benchmarking and parsing scripts

The script also handles the automatic detection of the system architecture and adjusts the setup process accordingly:

- On x86_64, standard build options are applied

- On ARM systems (e.g., Raspberry Pi), the script enables the Performance Monitoring Unit (PMU), installs kernel headers, and configures profiling support

The script is run interactively but supports the following optional arguments for advanced use:

| **Flag**                       | **Description**                                                                                                 |
|--------------------------------|-----------------------------------------------------------------------------------------------------------------|
| `--latest-dependency-versions` | Use the latest upstream versions of Liboqs and OQS-Provider (may cause compatibility issues with this project). |
| `--set-speed-new-value=<int>`  | Manually set `MAX_KEM_NUM` and `MAX_SIG_NUM` values in OpenSSL’s speed.c source file.                           |
| `--liboqs-memory-optimisation` | Enable liboqs algorithm memory optimisation feature for supported algorithms (disabled by default).             |
| `--help`                       | Display the help message for all supported options.                                                             |

For further information on the main setup script's usage, please refer to the main [README](../../README.md) and [Advanced Setup Configuration](../advanced_setup_configuration.md) file.

### cleaner.sh
This utility script is used for cleaning up files generated during the compiling and benchmarking processes. It provides options for uninstalling libraries (which includes deleting generated `__pycache__` directories), clearing old benchmarking results, and removing generated TLS keys. Users can choose to perform individual cleanup actions or both, based on their needs.

### configure_openssl_cnf.sh
This utility script manages the modification of the OpenSSL 4.0.3 openssl.cnf configuration file to support different stages of the PQC testing pipeline. It adjusts cryptographic provider settings and default group directives as required for:

- Initial setup

- Server certificate and private-key generation used in the TLS handshake testing

- TLS handshake performance benchmarking

These adjustments ensure compatibility with both OpenSSL's native PQC support and the OQS-Provider, depending on the testing context.

**Important:** It is strongly recommended that this script be used only as part of the automated testing framework. Manual use should be limited to recovery or debugging, as improper configuration may result in broken provider loading or handshake failures.

When called, the utility script accepts the following arguments:

| **Argument** | **Functionality**                                                                                                                                                                             |
|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `0`          | Performs initial setup by appending OQS-Provider-related directives to the `openssl.cnf` file. **This should only ever be called during setup when modifying the default OpenSSL conf file.** |
| `1`          | Configures the OpenSSL environment for **key generation benchmarking** by commenting out PQC-related configuration lines.                                                                     |
| `2`          | Configures the OpenSSL environment for **TLS handshake benchmarking** by uncommenting PQC-related configuration lines.                                                                        |

### get_algorithms.py
This Python utility script generates lists of supported cryptographic algorithms based on the currently installed versions of the Liboqs, OpenSSL (classic + PQC), and OQS-Provider libraries. These lists are stored under the `test_data/alg_lists` directory and are used by benchmarking, energy usage, TLS handshake transmission cost, and parsing tools to determine which algorithms to run or parse.

Primarily intended to be invoked by the `setup.sh` script, this utility accepts an argument that specifies the installation and testing context. However, it can also be run manually to regenerate the algorithm list files.

The script supports the following functionality:

- Extracts supported PQC KEM and digital signature algorithms from the Liboqs library using its built-in test binaries.

- Retrieves supported PQC and Hybrid-PQC TLS algorithms from OpenSSL and the OQS-Provider library.

- Generates lists of the supported classical TLS signing algorithms, key-exchange groups, and ciphersuites for supported TLS performance and energy usage testing.

- Parses the OQS-Provider’s `ALGORITHMS.md` file to determine the total number of supported algorithms (used by `setup.sh` and `source_code_modifier.sh` when configuring OpenSSL’s `speed.c`).

The utility script accepts the following arguments:

| **Argument** | **Functionality**                                                                                                                                                              |
|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1            | Extracts algorithms for **computational performance testing** (Liboqs algorithms only).                                                                                        |
| 2            | Extracts algorithms for **computational, TLS performance, TLS operations energy, and TLS handshake transmission cost testing** (Liboqs, OpenSSL, and OQS-Provider algorithms). |
| 3            | Extracts algorithms for **TLS performance, TLS operations energy, and TLS handshake transmission cost testing** (OpenSSL and OQS-Provider algorithms only).                    |
| 4            | Parses `ALGORITHMS.md` from OQS-Provider to determine the total number of supported algorithms (used only by `setup.sh`).                                                      |

Option `4` is used by the `source_code_modifier.sh` script to obtain the algorithm count when modifying OpenSSL’s `speed.c` during setup. Do not run it manually on a configured installation: the utility script currently clears existing algorithm lists during initialisation, even in this counting mode.

Example usage when running manually:

```
cd scripts/utility_scripts
python3 get_algorithms.py 1
```

### oid_handler.sh
This utility script manages custom OID environment variable mappings used only during TLS operations energy usage testing. It is an internal helper invoked by the TLS operations energy test script and is **not intended to be called manually**. It supports setting or clearing OID mappings so OpenSSL and OQS-Provider can reference private enterprise OIDs during performance test runs. This is required due to various algorithms included within OQS-Provider not having standardised OID values, which is required for the algorithm to be recognised as valid when being used in manual OpenSSL operations.

The utility script must be called with one of the following arguments in order to determine which OID handling operation must be performed:

| **Argument**     | **Functionality**                                           |
|------------------|-------------------------------------------------------------|
| --set-env-oids   | Set OID environment variables for quantum-safe algorithms   |
| --clear-env-oids | Clear OID environment variables for quantum-safe algorithms |
| --help           | Display the help message                                    |

The algorithms that are included within this script are based on the algorithms listed by OQS-Provider in their `ALGORITHMS.md` file (OQS-Provider version 0.12.0). Currently, the script is hard-coded to include the algorithms mentioned in that file. This will be updated in the future to be more dynamic. The version of the `ALGORITHMS.md` file used to dictate the algorithms included in this script can be found [here](https://github.com/open-quantum-safe/oqs-provider/blob/7e9d095aff7967fab9a8ce693e3da5357dc59d58/ALGORITHMS.md).

### serial_port_selector.py
This Python utility script is used for handling serial port selection in the energy testing bash scripts when serial control signalling has been selected by the user. The script uses the `pyserial` package to detect available serial ports on the system, outputs a numbered list of available ports to the user, validates the selected option value, and returns the selected serial device path to the calling Bash script. This utility script is intended to be called by the automated testing scripts (for example, `tls_operations_energy_test.sh` and `pqc_tls_performance_test.sh`) and is **not intended to be run manually**. To support properly grabbing the selected serial port path from the utility script in bash, interactive menu output and warning messages are written to standard error, while only the selected serial device path is written to standard output.

### source_code_modifier.sh
This internal utility script automates source code modifications for OpenSSL and OQS-Provider during the setup process. **It is not intended to be run manually from the terminal.** Depending on the setup configuration, the `setup.sh` script automatically invokes it to adjust hardcoded OpenSSL constants and enable algorithms that are disabled by default in OQS-Provider. It is located in the `scripts/utility_scripts/` directory.

It provides the following internal modification tools, each of which accepts its own set of arguments:

- **oqs_enable_algs** - Used for enabling OQS-Provider algorithms that are disabled by default.
- **modify_openssl_src** - Used to modify the OpenSSL `speed.c` source code to increase hardcoded values. Only called if disabled signature algorithms are re-enabled in OQS-Provider.

When calling the utility script, the first argument must always be the modification tool to use. If using the `modify_openssl_src` tool, additional arguments must be provided to specify specific modification values. If using the `oqs_enable_algs` tool, no additional arguments are required, as it automatically enables all disabled algorithms in OQS-Provider.

**Accepted Arguments for modify_openssl_src**:

| **Flag**                           | **Description**                                                                                                                                                                                        |
|------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `--user-defined-flag=[0\|1]`       | Set to `1` to use a manually specified value (via --user-defined-speed-value) instead of an automatically calculated value.                                                                            |
| `--user-defined-speed-value=[int]` | Specifies the new value to set for `MAX_KEM_NUM` and `MAX_SIG_NUM` in OpenSSL's `speed.c`. Must be a positive integer if `--user-defined-flag` is set to `1`. Use `0` if `--user-defined-flag` is `0`. |
| `--help`                           | Displays the help message for this tool. Intended primarily for debugging from within another script.                                                                                                  |


Example Usage includes:
```
source_code_modifier.sh "oqs_enable_algs"
```

```
source_code_modifier.sh "modify_openssl_src" "--user-defined-flag=1" "--user-defined-speed-value=500"
```

### system_state_configurer.sh
This utility script is used for configuring and restoring the system's performance state during energy usage evaluation testing. This helps improve measurement consistency, although background processes and thermal throttling can still affect results. It supports configuring the CPU governor setting and returning a target CPU core to be used by testing binaries*. It accepts one command line argument to set the default state, set custom state values, or restore the original configuration. Based on the detected command line argument, the script will either set the system state to a default configuration optimised for testing, or it will prompt the user to input custom values for the system state configuration. When using default settings, the CPU governor is set to performance and the second CPU core is selected when available (otherwise core 0).

**Required Command Line Arguments (one required):**

| **Argument**    | **Functionality**                                                                           |
|-----------------|---------------------------------------------------------------------------------------------|
| `--set-custom`  | Set custom CPU governor and CPU core values. Fan settings are prompted for but not applied. |
| `--set-default` | Set the system state to the default configuration optimised for testing.                    |
| `--restore`     | Restore the saved CPU governor setting.                                                     |
| `--help`        | Display the help message                                                                    |

* NOTE: Fan control is currently not supported in this version of PQC-LEO, but future development aims to include this functionality. In the meantime, **it is highly recommended** to set a manual fan speed to ensure consistent system thermal and power draw conditions during energy usage testing.

## Automated Computational Performance Testing Scripts
The computational performance testing suite benchmarks standalone PQC cryptographic operations for CPU and peak memory usage. It currently uses the Liboqs library and its testing tools to evaluate all supported KEM and digital signature algorithms. It is provided through a singular automation script which handles CPU and memory performance testing for PQC schemes. It is designed to be run interactively, prompting the user for test parameters such as the machine-ID to be assigned to the results and the number of test iterations.

### pqc_performance_test.sh
This script performs fully automated CPU and memory performance benchmarking of the algorithms included in the Liboqs library. It runs speed tests using Liboqs' built-in benchmarking binaries and uses Valgrind's massif tool to capture detailed peak memory usage metrics for each cryptographic operation. The results are stored in dedicated directories, organised by machine ID.

The script handles:

- Setting up environment and directory paths

- Prompting the user for test parameters (machine ID and number of runs)

- Performing speed and memory tests for each algorithm for the specified number of runs

- Organising raw result files for easy parsing
  
- Automatically calling the Python parsing scripts to process the raw performance results

#### Speed Test Functionality <!-- omit from toc -->
The speed test functionality benchmarks the execution time of KEM and digital signature algorithms using the Liboqs `speed_kem` and `speed_sig` tools. Raw performance results are saved to the `test_data/up_results/computational_performance/machine_x/raw_speed_results` directory.

#### Memory Testing Functionality <!-- omit from toc -->
Memory usage is profiled using the Liboqs `test_kem_mem` and `test_sig_mem` tools in combination with Valgrind’s Massif profiler. This setup captures detailed memory statistics for each cryptographic operation, recording values at the point of peak total memory consumption. Raw profiling data is initially stored in a temporary directory, then moved to `test_data/up_results/computational_performance/machine_x/mem_results`.

All results are saved in the `test_data/up_results/computational_performance/machine_x` directory, where x corresponds to the assigned machine ID. By default, these raw performance results will be parsed using the Python parsing scripts included within this project.

## Automated TLS Performance Testing Scripts
The PQC TLS performance testing suite relies on several scripts to carry out TLS benchmarking, including:

- pqc_tls_performance_test.sh
- tls_handshake_test_server.sh (Internal Script)
- tls_handshake_test_client.sh (Internal Script)
- tls_speed_test.sh (Internal Script)
- tls_generate_keys.sh

Testing scripts are stored in the `scripts/test_scripts` directory, whilst internal scripts are stored in the `scripts/test_scripts/internal_scripts` directory. Internal scripts are intended to be called by the main testing scripts and do not support being called in isolation.

### pqc_tls_performance_test.sh
This is the main controller script for executing the full TLS performance benchmarking suite. It performs TLS handshake testing for PQC, Hybrid-PQC, and classical configurations, together with cryptographic speed testing for PQC, Hybrid-PQC, and classical algorithms supported by OpenSSL 4.0.3 and the OQS-Provider. The script coordinates all required test operations by invoking subordinate scripts (`tls_handshake_test_server.sh`, `tls_handshake_test_client.sh`, and `tls_speed_test.sh`) and ensures that results are stored correctly under the appropriate machine directory based on the assigned Machine ID. Designed to run on both client and server machines, the script prompts the user for necessary parameters such as machine role, IP addresses, test duration, and number of runs. When run on the client, it configures both the handshake and speed benchmarking parameters accordingly.

It is important to note that when conducting testing, the `pqc_tls_performance_test.sh` script will prompt the user for parameters regarding the handling of storing and managing test results if the machine or current shell has been designated as the client (depending on whether single machine or separate machine testing is being performed).

Since version 0.6.0 of PQC-LEO, the controller script supports energy usage evaluation during TLS handshake benchmarking. This is currently supported on the client side of the testing suite and can be enabled by including the relevant command-line argument listed below when calling the controller script. By default, TLS handshake performance results are not stored when energy usage testing is enabled. During client configuration, however, the user can choose to store these results alongside the energy usage results. If storage is enabled, the performance results are written to the client machine and parsed without expecting TLS speed results, as TLS speed testing is skipped in this mode.

The script accepts the passing of various command-line arguments when called, which allows the user to configure components of the automated testing functionality. Please refer to the [TLS Performance Testing Instructions](../testing_tools_usage/tls_performance_testing.md) documentation file for further information on their usage.

**Accepted Script Arguments:**

| **Flag**                         | **Description**                                                                                                                       |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| `--server-control-port=<PORT>`   | Set the server control port   (1024-65535)                                                                                            |
| `--client-control-port=<PORT>`   | Set the client control port   (1024-65535)                                                                                            |
| `--s-server-port=<PORT>`         | Set the OpenSSL S_Server port (1024-65535)                                                                                            |
| `--control-sleep-time=<TIME>`    | Set the control sleep time in seconds (integer or float)                                                                              |
| `--disable-control-sleep`        | Disable the control signal sleep time                                                                                                 |
| `--enable-energy-testing`        | Enable energy testing, ensure the power measurement device is connected and configured correctly                                      |
| `--use-custom-eng-control-ports` | Enable the use of custom network control ports for energy testing control signalling (requires --enable-energy-testing to be enabled) |
| `--use-custom-sys-state`         | If performing energy testing, use custom system state values for the test instead of the default values.                              |
| `--help`                         | Display the help message                                                                                                              |

### tls_handshake_test_server.sh
This script handles the server-side operations for the automated TLS handshake performance testing. It tests PQC and Hybrid-PQC digital signature/KEM pairings, as well as every configured classical digital signature, key-exchange-group, and ciphersuite combination. The script includes error handling and coordinates with the client to retry failed tests using control signalling. This script is intended to be called only by the `pqc_tls_performance_test.sh` script and **cannot be run manually**.

### tls_handshake_test_client.sh
This script handles the client-side operations for the automated TLS handshake performance testing. It tests PQC and Hybrid-PQC digital signature/KEM pairings, as well as every configured classical digital signature, key-exchange-group, and ciphersuite combination. The script includes error handling and coordinates with the server to retry failed tests using control signalling. This script is intended to be called only by the `pqc_tls_performance_test.sh` script and **cannot be run manually**.

### tls_speed_test.sh
This script performs TLS cryptographic operation benchmarking with OpenSSL's `speed` command. It tests PQC and Hybrid-PQC digital signature and KEM operations implemented natively or through the OQS-Provider, together with a set of classical signature and key-exchange operations. Raw results are separated into `pqc`, `hybrid`, and `classic` speed directories. This script is intended to be called only by the `pqc_tls_performance_test.sh` script and **cannot be run manually**. It is only called if the machine or current shell has been designated as the client (depending on whether single-machine or separate-machine testing is performed).

### tls_generate_keys.sh
This script generates all certificates and private keys needed for TLS handshake performance and transmission cost testing. It creates a certificate authority (CA), server credentials, and client credentials for each PQC, Hybrid-PQC, and classical digital signature algorithm used in the tests. The client credentials enable mutual authentication during transmission cost testing. For performance tests conducted over a physical or virtual network, the generated key material must be copied to the client machine so both systems can access the required credentials.

This script must be called before conducting automated TLS handshake performance or transmission cost testing.

## Automated TLS Handshake Transmission Cost Testing Scripts
The TLS handshake transmission cost testing suite is implemented by the standalone `get_pqc_tls_bytes.py` script in the `scripts/test_scripts` directory. It uses the certificates generated by `tls_generate_keys.sh` and the project-managed OpenSSL and OQS-Provider builds.

### get_pqc_tls_bytes.py
This script measures the bytes transferred during local TLS 1.3 handshakes for PQC, Hybrid-PQC, and classical configurations. It starts an OpenSSL `s_server` on `127.0.0.1:4433`, connects with OpenSSL `s_client`, and extracts the handshake byte counts reported by the client. Every PQC/Hybrid-PQC signature and KEM pairing and every classical signature, key-exchange-group, and ciphersuite combination is tested with both one-way and mutual authentication.

The script prompts for a Machine-ID and writes three final CSV files, separated into PQC, Hybrid-PQC, and classical results, under `test_data/results/tls_handshake_bytes/machine_x`. These files are already structured and are not processed by `parse_results.py`. The script accepts no command-line arguments and is intended to be run directly after `tls_generate_keys.sh` has generated the required CA, server, and client credentials.

## Automated Energy Usage Testing Scripts
These scripts provide automated mechanisms for integrating energy usage evaluations into the existing PQC performance suites available within PQC-LEO. These bash scripts utilise the `comp_energy_tester` and `energy_collector` tools included within the framework to provide energy usage metrics for PQC computational and TLS performance. In doing, so the scripts provide a easy to use interface for interacting with these tools. For further information on the energy evaluation tools used by these scripts, please refer to the [Project Tools](./project_tools.md) documentation.

The following dedicated scripts handle this functionality:
- energy_metric_collector.sh
- pqc_performance_energy_test.sh
- tls_operations_energy_test.sh

Additionally, functionality is included within the `pqc_tls_performance_test.sh` and `tls_handshake_test_client.sh` scripts to provide automated TLS handshake energy usage evaluations. This section will describe the dedicated automation scripts.

### energy_metric_collector.sh
This controller script provides automation for the energy metric collector device using the `collector` binary included within the `energy_collector` tool. The script provides an interactive configuration interface for collection parameters (test type, machine ID, test runs), manages result directories and pre-existing result handling, and invokes the energy collector binary. It supports PQC performance, TLS handshake, and TLS operations collection types. The script will also automatically call the parsing script to parse results into structured CSV files via the central parser once testing has completed. Whilst the `collector` binary can be used by itself, this script provides an easy solution for result collection, handling, and parsing compared to manual use of the binary.

The `energy_collector` tool must be present within the PQC-LEO testing environment when calling this script, so please ensure that the relevant tools have been built using the `setup.sh` script. If the setup process sets that the energy tools should use the PQC-LEO OpenSSL build, the script will automatically configure the `LD_LIBRARY_PATH` to include the PQC-LEO OpenSSL build used by the energy tools.

**Accepted Script Arguments:**

| **Flag**                   | **Description**                                          |
|----------------------------|----------------------------------------------------------|
| `--disable-result-parsing` | Disable the automatic result parsing for the test suite. |
| `--help`                   | Display this help message.                               |

### pqc_performance_energy_test.sh
This controller script provides automation for the PQC computational performance energy benchmarking. The script utilises the `comp_energy_tester` binary included within `comp_energy_tester` tool to perform PQC cryptographic operations using the Liboqs library whilst sending control signals to the collector machine, allowing energy usage metrics to be gathered for each individual KEM/sig algorithm's respective operations. The script will call the `comp_energy_tester` after configuring the environment and system performance state using the `system_state_configurer.sh` utility script. The script accepts command line flags to enable custom system state configuration and custom network control ports for energy collector communication, and restores system state upon completion or interruption.

If the setup process sets that the energy tools should use the PQC-LEO OpenSSL build, the script will automatically configure the `LD_LIBRARY_PATH` to include the PQC-LEO OpenSSL build used by the energy tools.

**Accepted Script Arguments:**

| **Flag**                         | **Description**                                                                                           |
|----------------------------------|-----------------------------------------------------------------------------------------------------------|
| `--use-custom-sys-state`         | Used to indicate that custom system state values should be set for the test instead of the default values |
| `--use-custom-eng-control-ports` | Enable the use of custom network control ports for energy testing control signalling                      |
| `--help`                         | Display the help message                                                                                  |

### tls_operations_energy_test.sh
This controller script provides automation for TLS operations energy usage benchmarking. It measures the energy usage of PQC, Hybrid-PQC, and classical cryptographic operations performed directly through OpenSSL commands. The script tests key generation, encapsulation, and decapsulation for supported PQC/Hybrid-PQC KEMs; key generation, signing, and verification for PQC/Hybrid-PQC and classical signatures; and key generation and shared-secret derivation for classical key-exchange algorithms. It communicates with the collector device around each operation window, configures the system performance state through `system_state_configurer.sh`, and uses `oid_handler.sh` for PQC algorithms that require custom OID environment mappings. The script accepts command-line flags for custom system-state configuration and custom network control ports, and restores the system state on completion or interruption.

**Accepted Script Arguments:**

| **Flag**                         | **Description**                                                                                                                       |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| `--use-custom-sys-state`         | Used to indicate that custom system state values should be set for the test instead of the default values                             |
| `--use-custom-net-control-ports` | Enable the use of custom network control ports for energy collector communication.                                                    |
| `--help`                         | Display the help message                                                                                                              |

## Performance Data Parsing Scripts
The project includes several Python scripts that handle automatic parsing of benchmarking results:

- parse_results.py
- performance_data_parse.py
- tls_performance_data_parse.py
- energy_data_parse.py
- results_averager.py

These scripts support automated invocation (triggered by the automated test scripts) and manual execution via terminal input or command-line flags. Parsing is currently **supported only on Linux systems**. Windows environments are not supported due to the inability to create the environment needed to parse the raw performance results.

By default, parsing is triggered automatically at the end of each test run that produces a supported raw result type on the testing machine. The applicable test scripts directly pass the necessary parameters (Machine-ID, number of runs, and test type) to the parsing system. TLS handshake transmission cost testing is excluded because its script writes structured CSV files directly. When TLS handshake performance results are stored during energy usage testing, the TLS controller also instructs the parser to skip TLS speed results because those tests are not performed in this mode.

While several scripts are utilised for the result parsing process, only the `parse_results.py` is intended to be run directly. The main parsing script calls the remaining scripts depending on which parameters the user supplies to the script when prompted. The main parsing script is stored in the `scripts/parsing_scripts` directory, whilst internal scripts are stored in the `scripts/parsing_scripts/internal_scripts` directory.

For full documentation on how the parsing system works, including usage instructions and a breakdown of the performance metrics collected, please refer to the following documentation:

- [Parsing Performance Results Usage Guide](../performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](../performance_results/performance_metrics_guide.md)

### parse_results.py
This script acts as the main controller for the result-parsing processes. It supports two modes of operation:

- **Interactive Mode:** Prompts the user to select a result type (computational performance, TLS performance, or energy consumption) and to enter parsing parameters such as Machine-ID and number of test runs. If TLS performance parsing is selected, the script asks whether TLS speed results should be skipped. If energy parsing is selected, the script also prompts for the energy test type.

- **Command-Line Mode:** Accepts the same parameters via flags. The automated test scripts use this mode and can also be called manually for scripting purposes.

In both modes, the script identifies the relevant raw test results in the `test_data/up_results` directory and invokes the appropriate parsing routines to generate structured CSV output. The results are then saved to the `test_data/results` directory, organised by test type and Machine-ID.

**Usage Examples:**

Interactive Mode:

```
python3 parse_results.py
```

Command-Line Mode:

```
python3 parse_results.py --parse-mode=computational --machine-id=2 --total-runs=10
```

The table below outlines each of the accepted commands that are required for operation:

| **Argument**               | **Description**                                                                                                   | **Required Flag (*)** |
|----------------------------|-------------------------------------------------------------------------------------------------------------------|:---------------------:|
| `--parse-mode=<str>`       | Must be `computational`, `tls`, or `energy`.                                                                      |           *           |
| `--machine-id=<int>`       | Machine-ID used during testing (positive integer).                                                                |           *           |
| `--total-runs=<int>`       | Number of test runs (must be > 0).                                                                                |           *           |
| `--energy-test-type=<int>` | Required when `--parse-mode=energy`. 1=PQC computational energy, 2=TLS handshake energy, 3=TLS operations energy. |                       |
| `--replace-old-results`    | Optional flag to force overwrite any existing results for the specified Machine-ID.                               |                       |
| `--skip-tls-speed`         | When `--parse-mode=tls`, skip TLS speed parsing. Use when energy testing produces handshake results only.         |                       |

**Note:** The script parses one result type per run in both command-line and interactive modes. Run it again to parse a different result type.

### performance_data_parse.py
This script contains functions for parsing raw computational benchmarking data, transforming unstructured speed and memory test data into clean, structured CSV files. It processes CPU performance results and peak memory usage metrics gathered from Liboqs for each algorithm and operation across multiple test runs and machines. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### tls_performance_data_parse.py
This script processes TLS performance data collected from handshake and OpenSSL speed benchmarking using PQC, Hybrid-PQC, and classical algorithms. It parses the classical OpenSSL speed output into separate RSA, EC/Ed, ECDH, and XDH result files in addition to the PQC and Hybrid-PQC outputs, then generates per-run CSVs for analysis. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### energy_data_parse.py
This script processes the PQC computational and TLS energy usage testing results produced by the automated test scripts. Unlike other parsing scripts in PQC-LEO, the energy usage parsing script extracts all of the test metadata from the filename of the un-parsed result files, rather than a mix of filename and algorithm list text files, as seen in the other parsing scripts.

For TLS operations energy results, the parser classifies algorithms into `pqc`, `hybrid_pqc`, and `classic` groups. It writes the group CSVs to `pqc`, `hybrid`, and `classic` sub-directories beneath the machine results directory. The PQC groups contain KEM and signature CSVs, while the classical group contains signature and key-exchange CSVs, with a condensed per-run summary for each output. The TLS operations energy baseline CSV remains directly in the machine results directory.

The file naming format expected for each of the different types of energy usage testing results is as follows:

- **Computational Energy Usage Result** - `comp_(alg-type)_(operation)_(alg-name)_(run-number).txt`
- **PQC/Hybrid-PQC TLS Handshake Energy Result** - `tls_handshake_(session-id-type)_(signing-alg)@(kem-alg)_(run-number).txt`
- **Classical TLS Handshake Energy Result** - `tls_handshake_(session-id-type)_(signing-alg)@(key-exchange-group)@(ciphersuite)_(run-number).txt`
- **TLS Operations Energy Usage Result** - `tls_operations_(alg-type)_(operation)_(alg-name)_(run-number).txt`

### results_averager.py
This script provides the internal classes used to aggregate and condense parsed benchmarking results. It is used by `performance_data_parse.py` and `tls_performance_data_parse.py` to generate per-algorithm averages across multiple test runs, and is also used by `energy_data_parse.py` to create condensed per-run energy result sheets (min/max/avg/std for polled metrics and max-aggregated totals for cumulative metrics). For computational performance tests, it handles CPU speed and memory profiling metrics collected using Liboqs. For TLS performance tests, it calculates average handshake durations and cryptographic operation timings gathered from OpenSSL and OQS-Provider. For energy usage parsing, it groups each run by algorithm/operation context and computes structured summary metrics for easier analysis. This script is **not to be called manually** and only executes internally by the result parsing scripts.
