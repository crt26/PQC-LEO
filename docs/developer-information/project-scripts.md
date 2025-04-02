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
  - [configure-openssl-cnf.sh](#configure-openssl-cnfsh)
- [Liboqs Automated Testing Scripts](#liboqs-automated-testing-scripts)
  - [full-liboqs-test.sh](#full-liboqs-testsh)
- [OQS-Provider Automated Testing Scripts](#oqs-provider-automated-testing-scripts)
  - [full-oqs-provider-test.sh](#full-oqs-provider-testsh)
  - [oqsprovider-test-server.sh](#oqsprovider-test-serversh)
  - [oqsprovider-test-client.sh](#oqsprovider-test-clientsh)
  - [oqsprovider-test-speed.sh](#oqsprovider-test-speedsh)
  - [oqsprovider-generate-keys.sh](#oqsprovider-generate-keyssh)
- [Performance Data Parsing Scripts](#performance-data-parsing-scripts)
  - [parse\_results.py](#parse_resultspy)
  - [liboqs\_parse.py](#liboqs_parsepy)
  - [oqs\_provider\_parse.py](#oqs_provider_parsepy)
  - [results\_averager.py](#results_averagerpy)

## Project Utility Scripts
These utility scripts assist with development, testing, and environment setup. Most utility scripts are located in the `scripts/utility-scripts` directory, except `cleaner.sh` and `setup.sh`, which is placed in the project's root for convenience. The utility scripts are primarily designed to be called from the various automation scripts in the repository, but some can be called manually if needed.

The project utility scripts include the following:

- setup.sh
- cleaner.sh
- get_algorithms.py
- configure-openssl-cnf.sh

### setup.sh
This script automates the full environment setup for running the PQC benchmarking tools. It supports installing Liboqs, OQS-Provider, or both, based on user input, and configures the system accordingly.

Key tasks performed include:

- Installing all required system and Python dependencies (e.g., OpenSSL dev packages, CMake, Valgrind)

- Downloading and compiling OpenSSL 3.4.1

- Cloning and building specific or last-tested versions of Liboqs and OQS-Provider

- Modifying OpenSSL’s speed.c to support extended algorithm counts when needed

- Enabling optional OQS-Provider features (e.g., KEM encoders, disabled signature algorithms)

- Generating algorithm lists used by benchmarking and parsing scripts

The script also handles the automatic detection of the system architecture and adjusts the setup process accordingly:

- On x86_64, standard build options are applied

- On ARM systems (e.g., Raspberry Pi), the script enables the Performance Monitoring Unit (PMU), installs kernel headers, and configures profiling support

The script is run interactively but supports the following optional arguments for advanced use:

```
--safe-setup                   Use last-tested commits of all libraries  
--set-speed-new-value=<int>    Manually set MAX_KEM_NUM/MAX_SIG_NUM in speed.c  
```

For further information on the main setup script's usage, please refer to the main [README](../../README.md) file.

### cleaner.sh
This is a utility script for cleaning the various project files from the compiling and benchmarking operations. The script provides functionality for either uninstalling the OQS and other dependency libraries from the system, clearing the old results, algorithm list files, and generated TLS keys, or both.

### get_algorithms.py
This Python utility script generates lists of supported cryptographic algorithms based on the currently installed versions of the Liboqs and OQS-Provider libraries. These lists are stored under the `test-data/alg-lists` directory and are used by benchmarking and parsing tools to determine which algorithms to run. Additionally, the utility script can be used to parse the OQS-Provider `ALGORITHMS.md` file to determine the number of algorithms it supports.

The `setup.sh` script primarily invokes this script, where an argument is passed to determine the installation and testing context. However, it can also be run manually to regenerate the algorithm list files.

The script supports the following functionality:

- Extracts supported KEM and digital signature algorithms from the Liboqs library using its built-in test binaries

- Retrieves supported PQC and Hybrid-PQC TLS algorithms from the OQS-Provider via OpenSSL

- Generates hardcoded lists of classical TLS algorithms for baseline performance comparisons

- Parses the OQS-Provider’s `ALGORITHMS.md` file to determine the total number of supported algorithms (used by `setup.sh` when configuring OpenSSL’s `speed.c`)

The utility script accepts the following arguments:

| Argument | Functionality                                                                                                                 |
|----------|-------------------------------------------------------------------------------------------------------------------------------|
| `1`      | Extracts algorithms for **Liboqs only**.                                                                                      |
| `2`      | Extracts algorithms for **both Liboqs and OQS-Provider**.                                                                     |
| `3`      | Extracts algorithms for **OQS-Provider only**.                                                                                |
| `4`      | Parses `ALGORITHMS.md` from **OQS-Provider** to determine the total number of supported algorithms (used only by `setup.sh`). |

While running option `4` manually will work, it is unnecessary. This function is used exclusively by the `setup.sh` script to modify OpenSSL’s `speed.c` file when all OQS-Provider algorithms are enabled. Unlike the other arguments, it does not alter or create files in the repository; it only returns the algorithm count for use during setup.

Example usage when running manually:

```
cd scripts/utility-scripts
python3 get_algorithms.py 1
```

### configure-openssl-cnf.sh
This utility script modifies the OpenSSL 3.4.1 configuration file by commenting or uncommenting lines that define the default cryptographic groups. This adjustment is required for successful key generation and TLS handshake testing using the OQS-Provider. It is highly recommended to avoid manually calling this script to avoid any potential issues with misconfiguration in the `openssl.cnf` file. However, if issues do occur, it is advised to re-run the automatic setup process or restore a backup of the previous conf file's state.

The automated scripts mainly use this script, however it can be called manually using the following commands:

**configure-openssl-cnf.sh - (Comment out Default Group Configurations):**

```
./configure-openssl-cnf.sh 0
```

**configure-openssl-cnf.sh - (Uncomment out Default Group Configurations):**

```
./configure-openssl-cnf.sh 1
```

## Liboqs Automated Testing Scripts 
The Liboqs PQC performance testing utilises a single bash script to conduct the automated benchmarking. This script performs CPU speed testing and memory usage profiling for supported KEM and digital signature algorithms. It is designed to be run interactively, prompting the user for test parameters such as the machine ID and number of test iterations.

### full-liboqs-test.sh
This script performs fully automated CPU and memory performance benchmarking of the algorithms included in the Liboqs library. It runs speed tests using Liboqs' built-in benchmarking binaries and uses Valgrind with the massif tool to capture detailed memory usage metrics for each cryptographic operation. The results are stored in dedicated directories, organised by machine ID, and can be parsed later using the project's parsing tools.

The script handles:

- Setting up environment and directory paths

- Prompting the user for test parameters (machine ID and number of runs)

- Performing repeated speed and memory tests for each algorithm

- Organising raw result files for easy parsing

#### Speed Test Functionality <!-- omit from toc -->
The speed test functionality benchmarks the execution time of KEM and digital signature algorithms using the Liboqs `speed-kem` and `speed-sig` tools. Results are saved to the `test-data/up-results/liboqs/machine-x/raw-speed-results` directory.

#### Memory Testing Functionality <!-- omit from toc -->
Memory usage is profiled using the Liboqs `test-kem-mem` and `test-sig-mem` tools in combination with Valgrind’s Massif profiler. This setup captures detailed memory statistics for each cryptographic operation. Profiling data is initially stored in a temporary directory, then moved to `test-data/up-results/liboqs/machine-x/mem-results`.

All results are saved in the `test-data/up-results/liboqs/machine-x` directory, where x corresponds to the assigned machine ID.

## OQS-Provider Automated Testing Scripts
The Full PQC TLS Test tool uses several scripts to perform the TLS handshake tests. These include:

- full-oqs-provider-test.sh
- oqsprovider-test-server.sh
- oqsprovider-test-client.sh
- oqsprovider-test-speed.sh
- oqsprovider-generate-keys.sh

### full-oqs-provider-test.sh
This script is the main controller for executing the full TLS performance test suite using the OQS-Provider integration with OpenSSL. It is designed to be run on both the client and server machines and prompts the user for required parameters such as machine role, IP addresses, test duration, and number of runs. It coordinates the execution of all relevant test scripts (`oqsprovider-test-server.sh`, `oqsprovider-test-client.sh`, and `oqsprovider-test-speed.sh`). It ensures the results are stored correctly based on the assigned machine ID. When running on the client, it configures the TLS handshake and speed benchmarking test parameters.

It is important to note that when conducting testing, the `full-oqs-provider.sh` script will prompt the user for parameters regarding the handling of storing and managing test results if the machine or current shell has been designated as the client (depending on whether single machine or separate machine testing is being performed).

The script accepts the passing of various arguments when called, which allows the user to configure components of the automated testing functionality. For further information on their usage, please refer to the [TLS Performance Testing Instructions](../testing-tools-usage/oqsprovider-performance-testing.md) documentation file.

**Accepted Script Arguments:**

```
--server-control-port=<PORT>    Set the server control port   (1024-65535)
--client-control-port=<PORT>    Set the client control port   (1024-65535)
--s-server-port=<PORT>          Set the OpenSSL S_Server port (1024-65535)
--control-sleep-time=<TIME>     Set the control sleep time in seconds (integer or float)
--disable-control-sleep         Disable the control signal sleep time
```

### oqsprovider-test-server.sh
This script handles the server-side operations for the automated TLS handshake performance testing. It performs tests across various combinations of PQC and Hybrid-PQC digital signature and KEM algorithms, as well as classical-only handshakes. The script includes error handling and will coordinate with the client to retry failed tests using control signalling. This script is intended to be called only by the `full-oqs-provider.sh` script and **cannot be run manually**.

### oqsprovider-test-client.sh
This script handles the client-side operations for the automated TLS handshake performance testing. It performs tests across various combinations of PQC and Hybrid-PQC digital signature and KEM algorithms, as well as classical-only handshakes. The script includes error handling and will coordinate with the client to retry failed tests using control signalling. This script is intended to be called only by the `full-oqs-provider.sh` script and **cannot be run manually**.

### oqsprovider-test-speed.sh
This script handles the TLS computational performance testing when PQC and Hybrid-PQC algorithms are implemented into the `OpenSSL` library via `OQS-Provider`. It will gather CPU cycles data for the various cryptographic operations of the digital signature and KEM algorithms and store the results for later parsing. This script is intended to be called only by the `full-oqs-provider.sh` script and **cannot be run manually**. It is only called if the machine or current shell has been designated as the client (depending on whether single machine or separate machine testing is performed).

### oqsprovider-generate-keys.sh
This script generates all the certificates and private keys needed for TLS handshake performance testing. It creates a certificate authority (CA) and server certificate for each PQC, Hybrid-PQC, and classical digital signature algorithm and KEM used in the tests. The generated keys must be copied to the client machine before running handshake tests so both machines can access the required certificates. This is particularly relevant if conducting testing between two machines over a physical/virtual network.

This script must be called before conducting the automated TLS handshake performance testing.

## Performance Data Parsing Scripts
Various Python files included in the `scripts/parsing-scripts` directory provide the automatic result parsing functionality. These include:

- parse_results.py
- liboqs_parse.py
- oqs_provider_parse.py
- results_averager.py 

Unlike the other scripts within the repositories, this functionality can be performed in either Linux or Windows environments, assuming all required dependencies are present on the system. For further information on required dependencies, please refer to the **Parsing Script Usage** section in the main [README](../../README.md) file.

While several scripts are utilised for the result parsing process, only the `parse_results.py` is intended to be called manually. The main parsing script calls the remaining scripts depending on which parameters the user supplies to the script when prompted.

Please refer to the [Performance Metrics Guide](../performance-metrics-guide.md) for a detailed description of the performance metrics that this project can gather, what they mean, and how these scripts structure the un-parsed and parsed data.

### parse_results.py
This script acts as the main controller for the result-parsing processes. When called, the script will prompt the user for the various testing parameters such as:

- Which type of testing was performed
- How many machines were tested (facilitating the comparison between varying machine types)
- How many runs of testing were conducted on each of those machines

After gathering these parameters, the script will call the relevant sub-scripts to process the unparsed results in the `test-data/up-results` directory. The final output will store the parsed results in CSV format for the various tests performed, which can be found in the `test-data/results` directory.

**It is important to note** that if parsing results from multiple machines, the current limitations of the script require the same number of test runs to be performed. This will be addressed in future versions of the scripts. If parsing results from multiple machines where the types of tests conducted and the number of test runs do not match, it is best to perform the parsing of the data separately. Manual renaming can then be performed to fit the desired naming scheme.  

### liboqs_parse.py
This script contains functions for parsing un-parsed Liboqs benchmarking data, transforming unstructured speed and memory test data into clean, structured CSV files. It processes CPU performance results and memory usage metrics for each algorithm and operation across multiple test runs and machines. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### oqs_provider_parse.py
This script contains functions for parsing un-parsed OQS-Provider benchmarking data, transforming unstructured TLS handshake and speed test data into clean, structured CSV files. It processes performance metrics for PQC, hybrid-PQC, and classical algorithm combinations across multiple machines and test runs, outputting the results as structured CSV files. This script is **not to be called manually** and is only invoked by the `parse_results.py` script.

### results_averager.py
This script provides utility classes to compute average performance metrics from parsed benchmarking results. It is used by both `liboqs_parse.py` and `oqs_provider_parse.py` to generate per-algorithm averages across multiple test runs. It handles memory and CPU performance metrics for Liboqs tests and handshake and speed metrics for OQS-Provider TLS tests. This script is **not to be called manually** and is only executed internally by the result parsing scripts.