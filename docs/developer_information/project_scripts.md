# Project Scripts Documentation <!-- omit from toc --> 

## Overview <!-- omit from toc --> 
This document provides additional reference information for the various scripts in the repository. This documentation is designed primarily for developers or those who wish to better understand the core functionality of the project's various scripts.

The project's scripts are grouped into the following categories:

- The utility scripts
- The automated computational performance testing scripts
- The automated TLS performance testing scripts
- The raw performance data parsing scripts

It provides overviews of each script’s purpose, functionality, and any relevant parameters required when running the scripts manually.

### Contents <!-- omit from toc --> 
- [Project Utility Scripts](#project-utility-scripts)
  - [setup.sh](#setupsh)
  - [cleaner.sh](#cleanersh)
  - [get\_algorithms.py](#get_algorithmspy)
  - [configure\_openssl\_cnf.sh](#configure_openssl_cnfsh)
  - [source\_code\_modifier.sh](#source_code_modifiersh)
- [Automated Computational Performance Testing Scripts](#automated-computational-performance-testing-scripts)
  - [pqc\_performance\_test.sh](#pqc_performance_testsh)
- [Automated TLS Performance Testing Scripts](#automated-tls-performance-testing-scripts)
  - [pqc\_tls\_performance\_test.sh](#pqc_tls_performance_testsh)
  - [tls\_handshake\_test\_server.sh](#tls_handshake_test_serversh)
  - [tls\_handshake\_test\_client.sh](#tls_handshake_test_clientsh)
  - [tls\_speed\_test.sh](#tls_speed_testsh)
  - [tls\_generate\_keys.sh](#tls_generate_keyssh)
- [Performance Data Parsing Scripts](#performance-data-parsing-scripts)
  - [parse\_results.py](#parse_resultspy)
  - [performance\_data\_parse.py](#performance_data_parsepy)
  - [tls\_performance\_data\_parse.py](#tls_performance_data_parsepy)
  - [results\_averager.py](#results_averagerpy)

## Project Utility Scripts
These utility scripts assist with development, testing, and environment setup. Most utility scripts are located in the `scripts/utility_scripts` directory, except `cleaner.sh` and `setup.sh`, which are placed in the project's root for convenience. The utility scripts are primarily designed to be called from the various automation scripts in the repository, but some can be called manually if needed.

The project utility scripts include the following:

- setup.sh
- cleaner.sh
- get_algorithms.py
- configure_openssl_cnf.sh
- source_code_modifier.sh

### setup.sh
This script automates the full environment setup required to run the PQC benchmarking tools. It provides setup options for the different types of automated testing supported (computational, TLS, or both), and handles all necessary system configuration and dependency installation.

Key tasks performed include:

- Installing all required system and Python dependencies (e.g., OpenSSL dev packages, CMake, Valgrind)

- Downloading and compiling OpenSSL 3.5.0

- Cloning and building the last-tested or latest versions of Liboqs and OQS-Provider

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
| `--enable-liboqs-hqc-algs`     | Enable HQC KEM algorithms in Liboqs. Disabled by default due to spec non-conformance and security concerns.     |
| `--enable-oqs-hqc-algs`        | Enable HQC KEM algorithms in OQS-Provider. Requires Liboqs HQC to also be enabled.                              |
| `--enable-all-hqc-algs`        | Enable HQC KEM algorithms in both Liboqs and OQS-Provider. Overrides the other two HQC flags if present.        |
| `--help`                       | Display the help message for all supported options.                                                             |

For further information on the main setup script's usage, please refer to the main [README](../../README.md) and [Advanced Setup Configuration](../advanced_setup_configuration.md) file.

### cleaner.sh
This utility script is used for cleaning up files generated during the compiling and benchmarking processes. It provides options for uninstalling libraries (which includes deleting generated `__pycache__` directories), clearing old benchmarking results, and removing generated TLS keys. Users can choose to perform individual cleanup actions or both, based on their needs.

### get_algorithms.py
This Python utility script generates lists of supported cryptographic algorithms based on the currently installed versions of the Liboqs, OpenSSL (classic + PQC), and OQS-Provider libraries. These lists are stored under the `test_data/alg_lists` directory and are used by benchmarking and parsing tools to determine which algorithms to run and parse for the computational and TLS performance testing.

Primarily intended to be invoked by the `setup.sh` script, this utility accepts an argument that specifies the installation and testing context. However, it can also be run manually to regenerate the algorithm list files.

The script supports the following functionality:

- Extracts supported PQC KEM and digital signature algorithms from the Liboqs library using its built-in test binaries.

- Retrieves supported PQC and Hybrid-PQC TLS algorithms from OpenSSL and the OQS-Provider library.

- Generates hardcoded lists of classical TLS algorithms for baseline performance comparisons.

- Parses the OQS-Provider’s `ALGORITHMS.md` file to determine the total number of supported algorithms (used by `setup.sh` and `source_code_modifier.sh` when configuring OpenSSL’s `speed.c`).

The utility script accepts the following arguments:

| **Argument** | **Functionality**                                                                                                          |
|--------------|----------------------------------------------------------------------------------------------------------------------------|
| 1            | Extracts algorithms for **computational performance testing** (Liboqs algorithms only).                                    |
| 2            | Extracts algorithms for both **computational and TLS performance testing** (Liboqs, OpenSSL, and OQS-Provider algorithms). |
| 3            | Extracts algorithms for **TLS performance testing** (OpenSSL and OQS-Provider algorithms only).                            |
| 4            | Parses `ALGORITHMS.md` from OQS-Provider to determine the total number of supported algorithms (used only by `setup.sh`).  |

While running option `4` manually will work, it is unnecessary. This function is used exclusively by the `source_code_modifier.sh` script to modify OpenSSL’s `speed.c` file when all OQS-Provider algorithms are enabled. Unlike the other arguments, it does not alter or create files in the repository; it only returns the algorithm count for use during setup.

Example usage when running manually:

```
cd scripts/utility-scripts
python3 get_algorithms.py 1
```

### configure_openssl_cnf.sh
This utility script manages the modification of the OpenSSL 3.5.0 openssl.cnf configuration file to support different stages of the PQC testing pipeline. It adjusts cryptographic provider settings and default group directives as required for:

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

### source_code_modifier.sh
This internal utility script automates source code modifications for OpenSSL and OQS-Provider during the setup process. **It is not intended to be run manually from the terminal.** The `setup.sh` script automatically invokes it to adjust hardcoded OpenSSL constants, enable HQC algorithms, and re-enable signature algorithms disabled by default in OQS-Provider, depending on the setup configuration. It is located in the `scripts/utility_scripts/` directory. 

It provides the following internal modification tools, each of which accepts its own set of arguments:

- **oqs_enable_algs** - Used for enabling HQC KEM algorithms, enabling signature algorithms disabled by default, or both.
- **modify_openssl_src** - Used to modify the OpenSSL `speed.c` source code to increase hardcoded values. Only called if disabled signature algorithms are re-enabled in OQS-Provider.

When calling the utility script, the first argument must always be the modification tool to use. Subsequent arguments can be in any order, but must include all of the accepted arguments listed below for each tool.

**Accepted Arguments for oqs_enable_algs**:

| **Flag**                        | **Description**                                                                                       |
|---------------------------------|-------------------------------------------------------------------------------------------------------|
| `--enable-hqc-algs=[0\|1]`      | Set to `1` to enable HQC KEM algorithms in OQS-Provider by modifying the generate.yml file.           |
| `--enable-disabled-algs=[0\|1]` | Set to `1` to enable signature algorithms that are disabled by default in OQS-Provider.               |
| `--help`                        | Displays the help message for this tool. Intended primarily for debugging from within another script. |

**Accepted Arguments for modify_openssl_src**:

| **Flag**                           | **Description**                                                                                                                                                                                        |
|------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `--user-defined-flag=[0\|1]`       | Set to `1` to use a manually specified value (via --user-defined-speed-value) instead of an automatically calculated value.                                                                             |
| `--user-defined-speed-value=[int]` | Specifies the new value to set for `MAX_KEM_NUM` and `MAX_SIG_NUM` in OpenSSL's `speed.c`. Must be a positive integer if `--user-defined-flag` is set to `1`. Use `0` if `--user-defined-flag` is `0`. |
| `--help`                           | Displays the help message for this tool. Intended primarily for debugging from within another script.                                                                                                  |


Example Usage includes:
```
source_code_modifier.sh "oqs_enable_algs" "--enable-hqc-algs=1" "--enable-disabled-algs=1"
```

```
source_code_modifier.sh "modify_openssl_src" "--user-defined-flag=1" "--user-defined-speed-value=500"
```

## Automated Computational Performance Testing Scripts
The computational performance testing suite benchmarks standalone PQC cryptographic operations for CPU and memory usage. It currently uses the Liboqs library and its testing tools to evaluate all supported KEM and digital signature algorithms. It is provided through a singular automation script which handles CPU and memory performance testing for PQC schemes. It is designed to be run interactively, prompting the user for test parameters such as the machine-ID to be assigned to the results and the number of test iterations.

### pqc_performance_test.sh
This script performs fully automated CPU and memory performance benchmarking of the algorithms included in the Liboqs library. It runs speed tests using Liboqs' built-in benchmarking binaries and uses Valgrind's massif tool to capture detailed memory usage metrics for each cryptographic operation. The results are stored in dedicated directories, organised by machine ID.

The script handles:

- Setting up environment and directory paths

- Prompting the user for test parameters (machine ID and number of runs)

- Performing speed and memory tests for each algorithm for the specified number of runs

- Organising raw result files for easy parsing
  
- Automatically calling the Python parsing scripts to process the raw performance results

#### Speed Test Functionality <!-- omit from toc -->
The speed test functionality benchmarks the execution time of KEM and digital signature algorithms using the Liboqs `speed-kem` and `speed-sig` tools. Raw performance results are saved to the `test_data/up_results/computational_performance/machine_x/raw_speed_results` directory.

#### Memory Testing Functionality <!-- omit from toc -->
Memory usage is profiled using the Liboqs `test-kem-mem` and `test-sig-mem` tools in combination with Valgrind’s Massif profiler. This setup captures detailed memory statistics for each cryptographic operation. Raw profiling data is initially stored in a temporary directory, then moved to `test_data/up_results/computational_performance/machine_x/mem_results`.

All results are saved in the `test_data/up_results/computational_performance/machine_x` directory, where x corresponds to the assigned machine ID. By default, these raw performance results will be parsed using the Python parsing scripts included within this project.

## Automated TLS Performance Testing Scripts
The PQC TLS performance testing suite relies on several scripts to carry out TLS benchmarking, including:

- pqc_tls_performance_test.sh
- tls_handshake_test_server.sh (Internal Script)
- tls_handshake_test_client.sh (Internal Script)
- tls_speed_test.sh (Internal Script)
- tls_generate_keys.sh

Testing scripts are stored in the `scripts/testing_scripts` directory, whilst internal scripts are stored in the `scripts/testing_scripts/internal_scripts` directory. Internal scripts are intended to be called by the main testing scripts and do not support being called in isolation.

### pqc_tls_performance_test.sh
This is the main controller script for executing the full TLS performance benchmarking suite. It performs both TLS handshake and cryptographic speed testing for PQC, Hybrid-PQC, and classical algorithms supported by OpenSSL 3.5.0 and the OQS-Provider. The script coordinates all required test operations by invoking subordinate scripts (`tls_handshake_test_server.sh`, `tls_handshake_test_client.sh`, and `tls_speed_test.sh`) and ensures that results are stored correctly under the appropriate machine directory based on the assigned Machine ID. Designed to run on both client and server machines, the script prompts the user for necessary parameters such as machine role, IP addresses, test duration, and number of runs. When run on the client, it configures both the handshake and speed benchmarking parameters accordingly.

It is important to note that when conducting testing, the `pqc_tls_performance_test.sh` script will prompt the user for parameters regarding the handling of storing and managing test results if the machine or current shell has been designated as the client (depending on whether single machine or separate machine testing is being performed).

The script accepts the passing of various command-line arguments when called, which allows the user to configure components of the automated testing functionality. Please refer to the [TLS Performance Testing Instructions](../testing_tools_usage/tls_performance_testing.md) documentation file for further information on their usage.

**Accepted Script Arguments:**

| **Flag**                       | **Description**                                          |
|--------------------------------|----------------------------------------------------------|
| `--server-control-port=<PORT>` | Set the server control port   (1024-65535)               |
| `--client-control-port=<PORT>` | Set the client control port   (1024-65535)               |
| `--s-server-port=<PORT>`       | Set the OpenSSL S_Server port (1024-65535)               |
| `--control-sleep-time=<TIME>`  | Set the control sleep time in seconds (integer or float) |
| `--disable-control-sleep`      | Disable the control signal sleep time                    |

### tls_handshake_test_server.sh
This script handles the server-side operations for the automated TLS handshake performance testing. It performs tests across various combinations of PQC and Hybrid-PQC digital signature and KEM algorithms, as well as classical-only handshakes. The script includes error handling and will coordinate with the client to retry failed tests using control signalling. This script is intended to be called only by the `pqc_tls_performance_test.sh` script and **cannot be run manually**.

### tls_handshake_test_client.sh
This script handles the client-side operations for the automated TLS handshake performance testing. It performs tests across various combinations of PQC and Hybrid-PQC digital signature and KEM algorithms, as well as classical-only handshakes. The script includes error handling and will coordinate with the client to retry failed tests using control signalling. This script is intended to be called only by the `pqc_tls_performance_test.sh` script and **cannot be run manually**.

### tls_speed_test.sh
This script performs TLS cryptographic operation benchmarking. It tests the CPU performance of PQC, Hybrid-PQC, and classical digital signature and KEM operations implemented within OpenSSL (natively or via OQS-Provider). This script is intended to be called only by the `pqc_tls_performance_test.sh` script and **cannot be run manually**. It is only called if the machine or current shell has been designated as the client (depending on whether single-machine or separate-machine testing is performed).

### tls_generate_keys.sh
This script generates all the certificates and private keys needed for TLS handshake performance testing. It creates a certificate authority (CA) and server certificate for each PQC, Hybrid-PQC, and classical digital signature algorithm and KEM used in the tests. The generated keys must be copied to the client machine before running handshake tests so both machines can access the required certificates. This is particularly relevant if conducting testing between two machines over a physical/virtual network.

This script must be called before conducting the automated TLS handshake performance testing.

## Performance Data Parsing Scripts
The project includes several Python scripts that handle automatic parsing of benchmarking results:

- parse_results.py
- performance_data_parse.py
- tls_performance_data_parse.py
- results_averager.py

These scripts support automated invocation (triggered by the automated test scripts) and manual execution via terminal input or command-line flags. Parsing is currently **supported only on Linux systems**. Windows environments are not supported due to the inability to create the environment needed to parse the raw performance results.

By default, parsing is triggered automatically at the end of each test run. The test scripts directly pass the necessary parameters (Machine-ID, number of runs, and test type) to the parsing system.

While several scripts are utilised for the result parsing process, only the `parse_results.py` is intended to be run directly. The main parsing script calls the remaining scripts depending on which parameters the user supplies to the script when prompted. The main parsing script is stored in the `scripts/parsing_scripts` directory, whilst internal scripts are stored in the `scripts/parsing_scripts/internal_scripts` directory.

For full documentation on how the parsing system works, including usage instructions and a breakdown of the performance metrics collected, please refer to the following documentation:

- [Parsing Performance Results Usage Guide](../performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](../performance_results/performance_metrics_guide.md)

### parse_results.py
This script acts as the main controller for the result-parsing processes. It supports two modes of operation:

- **Interactive Mode:** Prompts the user to select a result type (computational performance, TLS performance, or both) and to enter parsing parameters such as Machine-ID and number of test runs.
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

| **Argument**            | **Description**                                                                     | **Required Flag (*)** |
|-------------------------|-------------------------------------------------------------------------------------|-----------------------|
| `--parse-mode=<str>`    | Must be either computational or tls, both is not allowed here.                      | *                     |
| `--machine-id=<int>`    | Machine-ID used during testing (positive integer).                                  | *                     |
| `--total-runs=<int>`    | Number of test runs (must be > 0).                                                  | *                     |
| `--replace-old-results` | Optional flag to force overwrite any existing results for the specified Machine-ID. |                       |

**Note:** The command-line mode does not support parsing both result types in one call. Use interactive mode to combine the parsing of computational performance and TLS performance data in a single session.

### performance_data_parse.py
This script contains functions for parsing raw computational benchmarking data, transforming unstructured speed and memory test data into clean, structured CSV files. It processes CPU performance results and memory usage metrics gathered from Liboqs for each algorithm and operation across multiple test runs and machines. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### tls_performance_data_parse.py
This script processes TLS performance data collected from handshake and OpenSSL speed benchmarking using PQC, Hybrid-PQC, and classical algorithms. It extracts timing and cycle count metrics from both TLS communication and cryptographic operations, outputting the results into clean CSV files for analysis. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### results_averager.py
This script provides the internal classes used to generate average benchmarking results across multiple test runs for the two testing types. It is used by both `performance_data_parse.py` and `tls_performance_data_parse.py` to generate per-algorithm averages across multiple test runs. For computational performance tests, it handles the collection of CPU speed and memory profiling metrics collected using Liboqs. For TLS performance tests, it calculates average handshake durations and cryptographic operation timings gathered from OpenSSL and OQS-Provider. This script is **not to be called manually** and only executes internally by the result parsing scripts.