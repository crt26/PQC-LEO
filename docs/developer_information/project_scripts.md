# Project Scripts Documentation <!-- omit from toc --> 

## Overview <!-- omit from toc --> 
This document provides additional reference information for the various scripts in the repository. This documentation is designed primarily for developers or those who wish to understand better the core functionality of the project's various scripts.

The scripts are grouped into the following categories:

- The project's utility scripts
- The Liboqs automated testing scripts
- The OQS-Provider automated testing scripts
- The performance data parsing scripts

It provides overviews of each script’s purpose, functionality, and any relevant parameters required when running the scripts manually.

### Contents <!-- omit from toc --> 
- [Project Utility Scripts](#project-utility-scripts)
  - [setup.sh](#setupsh)
  - [cleaner.sh](#cleanersh)
  - [get\_algorithms.py](#get_algorithmspy)
  - [configure\_openssl\_cnf.sh](#configure_openssl_cnfsh)
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
These utility scripts assist with development, testing, and environment setup. Most utility scripts are located in the `scripts/utility_scripts` directory, except `cleaner.sh` and `setup.sh`, which is placed in the project's root for convenience. The utility scripts are primarily designed to be called from the various automation scripts in the repository, but some can be called manually if needed.

The project utility scripts include the following:

- setup.sh
- cleaner.sh
- get_algorithms.py
- configure-openssl-cnf.sh

### setup.sh
This script automates the full environment setup for running the PQC benchmarking tools. It supports installing Liboqs, OQS-Provider, or both, based on user input, and configures the system accordingly.

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

| **Flag**                       | **Description**                                                                         |
|--------------------------------|-----------------------------------------------------------------------------------------|
| `--latest-dependency-versions` | Use the latest available versions of the OQS libraries (may cause compatibility issues) |
| `--set-speed-new-value=<int>`  | Manually set `MAX_KEM_NUM` and `MAX_SIG_NUM` in OpenSSL’s `speed.c`                     |
| `--enable-hqc-algs`            | Enable HQC KEM algorithms in Liboqs (default: disabled due to known vulnerability)      |

For further information on the main setup script's usage, please refer to the main [README](../../README.md) file.

### cleaner.sh
This is a utility script for cleaning the various project files from the compiling and benchmarking operations. The script provides functionality for either uninstalling the OQS and other dependency libraries from the system, clearing the old results, algorithm list files, and generated TLS keys, or both.

### get_algorithms.py
This Python utility script generates lists of supported cryptographic algorithms based on the currently installed versions of the Liboqs and OQS-Provider libraries. These lists are stored under the `test_data/alg_lists` directory and are used by benchmarking and parsing tools to determine which algorithms to run. Additionally, the utility script can be used to parse the OQS-Provider `ALGORITHMS.md` file to determine the number of algorithms it supports.

The `setup.sh` script primarily invokes this script, where an argument is passed to determine the installation and testing context. However, it can also be run manually to regenerate the algorithm list files.

The script supports the following functionality:

- Extracts supported KEM and digital signature algorithms from the Liboqs library using its built-in test binaries

- Retrieves supported PQC and Hybrid-PQC TLS algorithms from the OQS-Provider via OpenSSL

- Generates hardcoded lists of classical TLS algorithms for baseline performance comparisons

- Parses the OQS-Provider’s `ALGORITHMS.md` file to determine the total number of supported algorithms (used by `setup.sh` when configuring OpenSSL’s `speed.c`)

The utility script accepts the following arguments:

| **Argument** | **Functionality**                                                                                                             |
|--------------|-------------------------------------------------------------------------------------------------------------------------------|
| `1`          | Extracts algorithms for **Liboqs only**.                                                                                      |
| `2`          | Extracts algorithms for **both Liboqs and OQS-Provider**.                                                                     |
| `3`          | Extracts algorithms for **OQS-Provider only**.                                                                                |
| `4`          | Parses `ALGORITHMS.md` from **OQS-Provider** to determine the total number of supported algorithms (used only by `setup.sh`). |

While running option `4` manually will work, it is unnecessary. This function is used exclusively by the `setup.sh` script to modify OpenSSL’s `speed.c` file when all OQS-Provider algorithms are enabled. Unlike the other arguments, it does not alter or create files in the repository; it only returns the algorithm count for use during setup.

Example usage when running manually:

```
cd scripts/utility-scripts
python3 get_algorithms.py 1
```

### configure_openssl_cnf.sh
This utility script manages the modification of the OpenSSL 3.5.0 openssl.cnf configuration file to support different stages of the PQC testing pipeline. It adjusts cryptographic provider settings and default group directives as required for:

- Initial setup

- Key generation benchmarking

- TLS handshake benchmarking

These adjustments ensure compatibility with both OpenSSL's native PQC support and the OQS-Provider, depending on the testing context.

**Important:** It is strongly recommended that this script be used only as part of the automated testing framework. Manual use should be limited to recovery or debugging, as improper configuration may result in broken provider loading or handshake failures.

When called, the utility script accepts the following arguments:

| **Argument** | **Functionality**                                                                                                                                                                             |
|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `0`          | Performs initial setup by appending OQS-Provider-related directives to the `openssl.cnf` file. **This should only ever be called during setup when modifying the default OpenSSL conf file.** |
| `1`          | Configures the OpenSSL environment for **key generation benchmarking** by commenting out PQC-related configuration lines.                                                                     |
| `2`          | Configures the OpenSSL environment for **TLS handshake benchmarking** by uncommenting PQC-related configuration lines.                                                                        |

## Automated Computational Performance Testing Scripts
The computational performance testing suite benchmarks standalone PQC cryptographic operations for CPU and memory usage. It currently uses the Liboqs library and its testing tools to evaluate all supported KEM and digital signature algorithms. It is provided through a singular automation script which handles CPU and memory performance testing for PQC schemes. It is designed to be run interactively, prompting the user for test parameters such as the machine ID and number of test iterations.

### pqc_performance_test.sh
This script performs fully automated CPU and memory performance benchmarking of the algorithms included in the Liboqs library. It runs speed tests using Liboqs' built-in benchmarking binaries and uses Valgrind with the massif tool to capture detailed memory usage metrics for each cryptographic operation. The results are stored in dedicated directories, organised by machine ID.

The script handles:

- Setting up environment and directory paths

- Prompting the user for test parameters (machine ID and number of runs)

- Performing repeated speed and memory tests for each algorithm

- Organising raw result files for easy parsing

#### Speed Test Functionality <!-- omit from toc -->
The speed test functionality benchmarks the execution time of KEM and digital signature algorithms using the Liboqs `speed-kem` and `speed-sig` tools. Results are saved to the `test_data/up_results/computational_performance/machine_x/raw_speed_results` directory.

#### Memory Testing Functionality <!-- omit from toc -->
Memory usage is profiled using the Liboqs `test-kem-mem` and `test-sig-mem` tools in combination with Valgrind’s Massif profiler. This setup captures detailed memory statistics for each cryptographic operation. Profiling data is initially stored in a temporary directory, then moved to `test_data/up_results/computational_performance/machine_x/mem_results`.

All results are saved in the `test_data/up_results/computational_performance/machine_x` directory, where x corresponds to the assigned machine ID. By default, these raw performance results will be parsed using the Python parsing scripts included within this project.

## Automated TLS Performance Testing Scripts
The Full PQC TLS Test tool uses several scripts to conduct the TLS performance tests. These include:

- pqc_tls_performance_test.sh
- tls_handshake_test_server.sh (Internal Script)
- tls_handshake_test_client.sh (Internal Script)
- tls_speed_test.sh (Internal Script)
- tls_generate_keys.sh

Testing scripts are stored in the `scripts/testing_scripts` directory whilst internal scripts are stored in the `scripts/testing_scripts/internal_scripts` directory. Internal scripts are indented to be called by the main testing scripts and do not support being called in isolation.

### pqc_tls_performance_test.sh
This is the main controller script used to execute the full TLS performance benchmarking suite. This provides both TLS handshake and TLS speed testing for PQC, Hybrid-PQC and classical encryptions algorithms supported in both the OpenSSL 3.5.0 and OQS-Provider libraries. It automatically coordinates the execution of the TLS handshake and cryptographic speed tests by calling the appropriate subordinate scripts. All results are organised and stored under the relevant machine directory using the provided Machine-ID. It is designed to be run on both the client and server machines and prompts the user for required parameters such as machine role, IP addresses, test duration, and number of runs. It coordinates the execution of all relevant test scripts (`tls_handshake_test_server.sh`, `tls_handshake_test_client.sh`, and `tls_speed_test.sh`). It ensures the results are stored correctly based on the assigned machine ID. When running on the client, it configures the TLS handshake and speed benchmarking test parameters.

It is important to note that when conducting testing, the `pqc_tls_performance_test.sh` script will prompt the user for parameters regarding the handling of storing and managing test results if the machine or current shell has been designated as the client (depending on whether single machine or separate machine testing is being performed).

The script accepts the passing of various arguments when called, which allows the user to configure components of the automated testing functionality. For further information on their usage, please refer to the [TLS Performance Testing Instructions](../testing_tools_usage/tls_performance_testing.md) documentation file.

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
This script performs TLS cryptographic operation benchmarking. It tests the CPU performance of PQC, Hybrid-PQC, and classical digital signature and KEM operations as implemented within OpenSSL (either natively or via OQS-Provider). This script is intended to be called only by the `pqc_tls_performance_test.sh` script and **cannot be run manually**. It is only called if the machine or current shell has been designated as the client (depending on whether single machine or separate machine testing is performed).

### tls_generate_keys.sh
This script generates all the certificates and private keys needed for TLS handshake performance testing. It creates a certificate authority (CA) and server certificate for each PQC, Hybrid-PQC, and classical digital signature algorithm and KEM used in the tests. The generated keys must be copied to the client machine before running handshake tests so both machines can access the required certificates. This is particularly relevant if conducting testing between two machines over a physical/virtual network.

This script must be called before conducting the automated TLS handshake performance testing.

## Performance Data Parsing Scripts
Various Python files included in the project provide the automatic result parsing functionality. These include:

- parse_results.py
- performance_data_parse.py
- tls_performance_data_parse.py
- results_averager.py

These scripts support both automated invocation (triggered by the automated test scripts) and manual execution via terminal input or command-line flags. Parsing is currently **supported only on Linux systems**. Windows environments are not supported due to the inability to create the necessary environment needed for parsing the raw performance results.

By default, parsing is triggered automatically at the end of each test run. The test scripts pass the necessary parameters (Machine-ID, number of runs, and test type) directly to the parsing system.

While several scripts are utilised for the result parsing process, only the `parse_results.py` is intended to be called. The main parsing script calls the remaining scripts depending on which parameters the user supplies to the script when prompted. The main parsing script is stored in the `scripts/parsing_scripts` directory whilst internal scripts are stored in the `scripts/parsing_scripts/internal_scripts` directory.

For full documentation on how the parsing system works, including usage instructions and a breakdown of the performance metrics collected, please refer to the following documentation:

- [Parsing Performance Results Usage Guide](../performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](../performance_results/performance_metrics_guide.md)

### parse_results.py
This script acts as the main controller for the result-parsing processes. It supports two modes of operation:

- **Interactive Mode:** Prompts the user to select a result type (computational performance, tls performance, or both) and to enter parsing parameters such as Machine-ID and number of test runs.
- **Command-Line Mode:** Accepts the same parameters via flags. This mode is used by the automated test scripts and can also be called manually for scripting purposes.

In both modes, the script identifies the relevant raw test results located in the `test_data/up_results` directory and invokes the appropriate parsing routines to generate structured CSV output. The results are then saved to the `test_data/results` directory, organised by test type and Machine-ID.

**Usage Examples:**

Interactive Mode:

```
python3 parse_results.py
```

Command-Line Mode:

```
python3 parse_results.py --parse-mode=computational --machine-id=2 --total-runs=10
```

The table below outlines each of the accepted commands and which are required for operation:

| **Argument**            | **Description**                                                                        | **Required Flag (*)** |
|-------------------------|----------------------------------------------------------------------------------------|-----------------------|
| `--parse-mode=<str>`    | Must be either computational or tls. both is not allowed here.                         | *                     |
| `--machine-id=<int>`    | Machine-ID used during testing (positive integer).                                     | *                     |
| `--total-runs=<int>`    | Number of test runs (must be > 0).                                                     | *                     |
| `--replace-old-results` | Optional flag to force overwrite of any existing results for the specified Machine-ID. |                       |

**Note:** The command-line mode does not support parsing both result types in one call. Use interactive mode to combine parsing of computational performance and TLS performance data in a single session.

### performance_data_parse.py
This script contains functions for parsing un-parsed computational benchmarking data, transforming unstructured speed and memory test data into clean, structured CSV files. It processes CPU performance results and memory usage metrics gathered from Liboqs for each algorithm and operation across multiple test runs and machines. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### tls_performance_data_parse.py
This script processes TLS performance data collected from handshake and OpenSSL speed benchmarking using PQC, Hybrid-PQC, and classical algorithms. It extracts timing and cycle count metrics from both TLS communication and cryptographic operations, outputting the results into clean CSV files for analysis. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### results_averager.py
This script provides the internal classes used to generate average benchmarking results across multiple test runs for the two testing types. It is used by both `performance_data_parse.py` and `tls_performance_data_parse.py` to generate per-algorithm averages across multiple test runs. For computational performance tests, it handles the collection of CPU speed and memory profiling metrics collected using Liboqs. For TLS performance tests, it calculates average handshake durations and cryptographic operation timings gathered from OpenSSL with the OQS-Provider. This script is **not to be called manually** and is only executed internally by the result parsing scripts.