# PQC Performance Metrics & Results Storage Breakdown <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides a comprehensive guide to the PQC computational performance, TLS performance, TLS handshake transmission cost, and energy usage metrics collected by the project's automated benchmarking tools. It describes the types of metrics gathered and how test data is structured, parsed where required, and analysed across different environments using the provided testing and parsing scripts.

Specifically, it covers:

- An overview of the core cryptographic operations used in PQC digital signature schemes and Key Encapsulation Mechanisms (KEMs)

- A breakdown of the computational performance metrics gathered via Liboqs benchmarking tools, including how these results are stored and organised

- A description of TLS performance metrics obtained from testing OpenSSL’s native PQC support and OQS-Provider, along with their storage and processing structure

- A description of the TLS handshake transmission cost metrics gathered for one-way and mutual authentication, along with their result structure

- A description of the energy usage metrics collected during computational and TLS performance testing, including the specific metrics gathered and how this data is stored for analysis

### Contents <!-- omit from toc -->
- [Description of Post-Quantum Cryptographic Operations](#description-of-post-quantum-cryptographic-operations)
- [PQC Computational Performance metrics](#pqc-computational-performance-metrics)
  - [CPU Benchmarking](#cpu-benchmarking)
  - [Memory Benchmarking](#memory-benchmarking)
- [Computational Performance Result Data Storage Structure](#computational-performance-result-data-storage-structure)
- [PQC TLS Performance Metrics](#pqc-tls-performance-metrics)
  - [TLS Handshake Testing](#tls-handshake-testing)
  - [TLS Speed Testing](#tls-speed-testing)
- [TLS Performance Result Data Storage Structure](#tls-performance-result-data-storage-structure)
- [TLS Handshake Transmission Cost Metrics](#tls-handshake-transmission-cost-metrics)
- [TLS Handshake Transmission Cost Result Data Storage Structure](#tls-handshake-transmission-cost-result-data-storage-structure)
- [PQC Energy Usage Metrics](#pqc-energy-usage-metrics)
  - [Collected Energy Usage Metrics](#collected-energy-usage-metrics)
  - [PQC Computational Energy Usage](#pqc-computational-energy-usage)
  - [TLS Handshake Energy Usage](#tls-handshake-energy-usage)
  - [TLS Speed Energy Usage](#tls-speed-energy-usage)
- [Energy Usage Metrics Result Data Storage Structure](#energy-usage-metrics-result-data-storage-structure)
- [Useful External Documentation](#useful-external-documentation)

## Description of Post-Quantum Cryptographic Operations
Post-Quantum Cryptography (PQC) algorithms are separated into two categories: Digital Signature Schemes and Key Encapsulation Mechanisms (KEMs). Each category has three cryptographic operations defining the algorithm’s core functionality.

This section provides a brief overview of these operations to support the performance metrics descriptions detailed later in this document.

### Digital Signature Operations <!-- omit from toc --> 

| **Operation Name** | **Internal Label** | **Description**                                                          |
|--------------------|--------------------|--------------------------------------------------------------------------|
| Key Generation     | keypair            | Generates a public/private key pair for the digital signature algorithm. |
| Signing            | sign               | Uses the private key to generate a digital signature over a message.     |
| Verification       | Verify             | Uses the public key to verify the authenticity of a digital signature.   |

### Key Encapsulation Mechanism (KEM) Operations <!-- omit from toc --> 

| **Operation Name** | **Internal Label** | **Description**                                                        |
|--------------------|--------------------|------------------------------------------------------------------------|
| Key Generation     | keygen             | Generates a public/private key pair for the KEM algorithm.             |
| Encapsulation      | encaps             | Uses the public key to generate a shared secret and ciphertext.        |
| Decapsulation      | decaps             | Uses the private key to recover the shared secret from the ciphertext. |

## PQC Computational Performance metrics
The computational performance tests collect detailed CPU and peak memory usage metrics for PQC digital signature and KEM algorithms. Using the Liboqs library, the automated testing tool performs each cryptographic operation and outputs the results, which are separated into two categories: CPU benchmarking and memory benchmarking.

### CPU Benchmarking
The CPU benchmarking results measure the execution time and efficiency of various cryptographic operations for each PQC algorithm. Using the Liboqs `speed_kem` and `speed_sig` benchmarking tools, each operation is run repeatedly within a fixed time window (3 seconds by default). The tool performs as many iterations as possible in that time frame and records detailed performance metrics.

The table below describes the metrics included in the CPU benchmarking results:

| **Metric**          | **Description**                                                           |
|---------------------|---------------------------------------------------------------------------|
| Iterations          | Number of times the operation was executed during the test window.        |
| Total Time (s)      | Total duration of the test run (typically fixed at 3 seconds).            |
| Time (us): mean     | Average time per operation in microseconds.                               |
| pop. stdev          | Population standard deviation of the operation time, indicating variance. |
| CPU cycles: mean    | Average number of CPU cycles required per operation.                      |
| pop. stdev (cycles) | Standard deviation of CPU cycles per operation, indicating consistency.   |

### Memory Benchmarking
The memory benchmarking tool evaluates how much memory individual PQC cryptographic operations consume when executed on the system. This is accomplished by running the `test_kem_mem` and `test_sig_mem` Liboqs tools for each PQC algorithm and its respective operations with the Valgrind Massif profiler. Each operation is performed once with the Valgrind Massif profiler to gather memory usage values at the point of peak total memory consumption. Tests can be repeated across multiple runs to ensure consistency.

The following table describes the memory-related metrics captured after the result parsing process has been completed:

| **Metric** | **Description**                                                                 |
|------------|---------------------------------------------------------------------------------|
| inits      | Number of memory snapshots (or samples) collected by Valgrind during profiling. |
| peakBytes  | Total memory usage across all memory segments (heap + stack + others) at peak.  |
| Heap       | Heap memory usage at the time of peak total memory consumption.                 |
| extHeap    | Externally allocated heap memory (e.g., from system libraries) at peak usage.   |
| Stack      | Stack memory usage at the time of peak total memory consumption.                |

## Computational Performance Result Data Storage Structure
All performance data is initially stored as unparsed output when using the computational performance benchmarking script (`pqc_performance_test.sh`). This raw data is then automatically processed using the Python parsing script to generate structured CSV files for analysis, including averages across test runs.

The table below outlines where this data is stored and how it's organised in the project's directory structure:

| **Data Type**        | **State** | **Description**                                              | **Location** *(relative to `test_data/`)*                           |
|----------------------|-----------|--------------------------------------------------------------|---------------------------------------------------------------------|
| CPU Speed            | Un-parsed | Raw `.csv` outputs from `speed_kem` and `speed_sig`.         | `up_results/computational_performance/machine_x/raw_speed_results/` |
| CPU Speed            | Parsed    | Cleaned CSV files with metrics and averages.                 | `results/computational_performance/machine_x/speed_results/`        |
| Memory Usage         | Un-parsed | Valgrind Massif `.txt` outputs from signature/KEM profiling. | `up_results/computational_performance/machine_x/mem_results/`       |
| Memory Usage         | Parsed    | CSV summaries of peak memory usage.                          | `results/computational_performance/machine_x/mem_results/`          |
| Performance Averages | Parsed    | Averaged metrics across test runs.                           | `results/computational_performance/machine_x/`                      |

Where `machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be set for the results.

## PQC TLS Performance Metrics
The TLS performance testing suite benchmarks PQC, Hybrid-PQC, and classical algorithm configurations available through both OpenSSL's native support and the OQS-Provider. OpenSSL 4.0.1 provides native PQC implementations alongside those exposed by the OQS-Provider, and the suite is designed to evaluate performance consistently across the available implementations. It measures performance within the TLS 1.3 handshake protocol and the execution speed of cryptographic operations directly through OpenSSL. This provides insight into how PQC schemes perform in real-world security protocol scenarios. An expanded set of classical digital signature algorithms, key-exchange groups, and ciphersuites is also tested to establish performance baselines for comparison with PQC and Hybrid-PQC algorithms.

As part of the automated TLS testing, two categories of evaluations are conducted:

- **TLS Handshake Testing** - This simulates full TLS 1.3 handshakes using OpenSSL’s `s_server` and `s_time` tools, evaluating both standard and session-resumed connections.

- **TLS Speed Testing** - This uses the OpenSSL `speed` tool to benchmark low-level operations such as key generation, encapsulation, signing, verification, and key derivation.

### TLS Handshake Testing
The TLS handshake performance tests measure how efficiently different PQC, Hybrid-PQC, and classical algorithm combinations perform during the TLS 1.3 handshake process. These tests are executed using OpenSSL's built-in benchmarking tools (`s_server` and `s_time`).

For PQC and Hybrid-PQC, each test uses a signing-algorithm and KEM pairing. Classical tests instead use a signing-algorithm, key-exchange-group, and ciphersuite combination. Every TLS handshake configuration is performed as many times as possible during the set testing time window, both with and without session ID reuse, to evaluate the overall performance.

The table below describes the performance metrics gathered during this testing:

| **Metric**                                  | **Description**                                                                                                   |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| Connections in User Time                    | Number of successful TLS handshakes completed during CPU/user time. Reflects algorithm efficiency per CPU second. |
| Connections per User Second                 | Handshake rate per CPU second. Indicates performance under ideal CPU conditions.                                  |
| Real-Time                                   | Total wall clock time elapsed, including system I/O and process delays.                                           |
| Connections in Real Time                    | Number of handshakes completed in actual wall time. Useful for real-world performance assessment.                 |
| Connections per User Second (Session Reuse) | Handshake rate per CPU second with session ID reuse. Measures efficiency with session resumption.                 |
| Connections in Real Time (Session Reuse)    | Handshakes per real-world time with session reuse. Reflects practical performance with resumed sessions.          |

When averaged TLS handshake result files are generated, additional columns are included alongside the standard metrics:

| **Column**            | **Description**                                                      |
|-----------------------|----------------------------------------------------------------------|
| Runs used for Average | The number of test runs included in the average calculation.         |
| Total Runs            | The total number of test runs performed for the given configuration. |

These columns are used to indicate how many test runs were included in each average calculation. This is necessary because, in some cases, a value of `inf` may be produced for the **"Connections per User Second"** metric when using shorter TLS handshake test durations.

If an `inf` value occurs in a run, that run is excluded from the average calculation for the affected algorithm combination. The additional columns allow users to determine whether any runs were excluded and how many valid runs contributed to the final averaged result. This information on the number of runs used is only present for TLS handshake results, as all other types of testing are always able to use all test runs performed for average calculations.

Further information on this behaviour and how it can be avoided is provided in the [TLS Handshake Inf Result Handling](./tls_handshake_inf_result_handling.md) documentation.

### TLS Speed Testing
TLS speed testing benchmarks the raw cryptographic performance of PQC, Hybrid-PQC, and classical algorithms within OpenSSL. It uses both OpenSSL-native algorithms and PQC algorithms provided by the OQS-Provider. The test uses OpenSSL's `speed` tool to measure operation time and throughput for PQC/Hybrid-PQC KEM and signature algorithms, classical RSA/EC/Ed signature algorithms, and classical ECDH/XDH key-exchange algorithms.

Classical RSA speed results are reported only by modulus size, such as `RSA_2048`, because `openssl speed` does not expose a separate RSA-PSS selector or result category. Its standard RSA selectors use the RSA/PKCS#1 v1.5 path. Consequently, standard TLS speed output does not contain `RSA-PSS_*` rows.

The primary objective of this test is to gather the base system performance of the schemes when integrated into the OpenSSL library. The results provide insight into the algorithm's standalone efficiency when running within OpenSSL, which can produce additional overhead compared to the performance tests provided by the computational performance testing suite.

#### Digital Signature Algorithm Metrics
The following table describes the metrics collected for PQC/Hybrid-PQC signatures and classical RSA signatures during TLS speed testing:

| **Metric** | **Description**                                           |
|------------|-----------------------------------------------------------|
| keygen (s) | Average time in seconds to generate a signature key pair. |
| sign (s)   | Average time in seconds to perform a signing operation.   |
| verify (s) | Average time in seconds to verify a digital signature.    |
| keygens/s  | Number of key generation operations completed per second. |
| signs/s    | Number of signing operations completed per second.        |
| verifies/s | Number of verification operations completed per second.   |

#### KEM Algorithm Metrics
The following table describes the metrics collected for PQC/Hybrid-PQC KEMs and classical XDH algorithms during TLS speed testing:

| **Metric** | **Description**                                                |
|------------|----------------------------------------------------------------|
| keygen (s) | Average time in seconds to generate a keypair.                 |
| encaps (s) | Average time in seconds to perform an encapsulation operation. |
| decaps (s) | Average time in seconds for decapsulation operation.           |
| keygens/s  | Number of key generation operations completed per second.      |
| encaps/s   | Number of encapsulation operations completed per second.       |
| decaps/s   | Number of decapsulation operations completed per second.       |

Classical ECDH result files instead report `op (s)` and `op/s`, representing the average time and throughput for shared-secret derivation.

## TLS Performance Result Data Storage Structure
When running the TLS benchmarking script (`pqc_tls_performance_test.sh`), all performance data is initially stored as unparsed output. This includes both handshake and speed test results. After testing, the parsing script processes this raw data into structured CSV files, including calculated averages across test runs.

| **Data Type**   | **State**     | **Description**                                                                                 | **Location** *(relative to `test_data/`)*                                         |
|-----------------|---------------|-------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| TLS Handshake   | Un-parsed     | Raw `.txt` outputs from OpenSSL `s_time` tests for PQC, Hybrid-PQC, and classical combinations. | `up_results/tls_performance/machine_x/handshake_results/{pqc/hybrid/classic}`     |
| TLS Handshake   | Parsed        | Per-run PQC and Hybrid-PQC CSVs organised by signing algorithm.                                 | `results/tls_performance/machine_x/handshake_results/{pqc/hybrid}/{signature}`    |
| TLS Handshake   | Parsed        | Combined per-run and averaged CSVs for all classical signature/group/ciphersuite combinations.  | `results/tls_performance/machine_x/handshake_results/classic/`                    |
| TLS Handshake   | Parsed (Base) | Combined CSVs aggregating all PQC/Hybrid-PQC signature/KEM combinations for each run.           | `results/tls_performance/machine_x/handshake_results/{pqc/hybrid}/base_results`   |
| TLS Speed       | Un-parsed     | Raw `.txt` outputs from OpenSSL speed tests for PQC, Hybrid-PQC, and classical algorithms.      | `up_results/tls_performance/machine_x/speed_results/{pqc/hybrid/classic}`         |
| TLS Speed       | Parsed        | Per-run CSVs and averages with cryptographic operation timings and throughput.                  | `results/tls_performance/machine_x/speed_results/{pqc/hybrid/classic}`            |
| Parsed Averages | Parsed        | Averaged handshake and speed results across test runs.                                          | Stored alongside parsed result files in `results/tls_performance/machine_x/`      |

Where `machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be set for the results.

Raw classical handshake files use a different naming convention to PQC/Hybrid-PQC files:

`tls_handshake_classic_(run-number)_(signing-alg)_(key-exchange-group)_(ciphersuite).txt`.

Parsing combines these into `classic_results_run_(run-number).csv` and produces `classic_results_avg.csv`; both CSV formats retain separate `Signing Algorithm`, `Key Exchange Group`, and `Ciphersuite` columns.

Raw classical speed files are named `tls_speed_classic_sig_(run-number).txt` and `tls_speed_classic_key_exchange_(run-number).txt`. Parsing separates their OpenSSL result tables into `sig_ec`, `sig_rsa`, `key_exchange_ecdh`, and `key_exchange_xdh` per-run CSVs, with a corresponding `_avg.csv` file for each category.

## TLS Handshake Transmission Cost Metrics
The TLS handshake transmission cost test measures the network data exchanged during TLS 1.3 handshakes for PQC, Hybrid-PQC, and classical configurations. PQC and Hybrid-PQC tests use signing-algorithm/KEM pairings, while classical tests use signing-algorithm/key-exchange-group/ciphersuite combinations. The tool performs one handshake with one-way authentication and one handshake with mutual authentication for every configuration. The measurements are extracted from the summary produced by OpenSSL `s_client` output.

| **Metric**     | **Description**                                                |
|----------------|----------------------------------------------------------------|
| Bytes Sent     | Number of bytes written by the TLS client during the handshake |
| Bytes Received | Number of bytes read by the TLS client during the handshake    |
| Total Bytes    | Sum of the bytes sent and received during the handshake        |

Each result row also identifies the signature algorithm and authentication type (`one_way_auth` or `mutual_auth`). PQC and Hybrid-PQC rows identify the KEM algorithm; classical rows instead identify both the key-exchange group and ciphersuite. Unlike the TLS performance suite, this test records a single handshake per configuration and does not calculate run averages.

## TLS Handshake Transmission Cost Result Data Storage Structure
The `get_pqc_tls_bytes.py` script writes structured CSV data directly, so there is no unparsed result directory or additional parsing stage.

| **Data Type**                  | **Description**                                                                                     | **Location** *(relative to `test_data/`)*                                       |
|--------------------------------|-----------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| PQC TLS Handshake Bytes        | Transmission-cost results for PQC signature and KEM combinations                                    | `results/tls_handshake_bytes/machine_x/pqc_tls_handshake_bytes_results.csv`     |
| Hybrid-PQC TLS Handshake Bytes | Transmission-cost results for Hybrid-PQC signature and KEM combinations                             | `results/tls_handshake_bytes/machine_x/hybrid_tls_handshake_bytes_results.csv`  |
| Classical TLS Handshake Bytes  | Transmission-cost results for classical signature, key-exchange-group, and ciphersuite combinations | `results/tls_handshake_bytes/machine_x/classic_tls_handshake_bytes_results.csv` |

Where `machine_x` is the Machine-ID selected when the script is executed. If no custom Machine-ID is assigned, the default ID of 1 is used.

## PQC Energy Usage Metrics
The energy usage metrics collected by the project’s automated testing tools provide insight into the power consumption of PQC algorithms during both computational performance tests and TLS performance tests. These metrics are gathered using energy meters connected to the system, which measure the total energy consumed during the execution of cryptographic operations and TLS handshakes.

PQC-LEO provides automation scripts for collecting energy usage data for the following testing categories:
- PQC computational energy usage
- TLS handshake energy usage
- TLS speed energy usage

However, as the tools provided by the framework for gathering these metrics can be used outwith the automated testing suite, it is possible to gather energy usage metrics outwith the context of the provided testing scripts. This documentation will provide information on the above mentioned categories and provides a description of what values can be collected in general when using the energy usage collection tools outwith the context of the provided testing scripts.

As part of the evaluation process for each of the testing categories above, the automated testing scripts will gather a usage baseline for the system. This is done by sleeping for a period of 10 seconds whilst the energy meter is polled during this testing window. This data provides insight into the idle energy consumption of the device, allowing a meaningful comparison to be made between the energy consumed during testing and the baseline energy usage of the system. The data fields in this file will only include the raw usage metrics shown below in the energy usage metrics section of this document, and will not include any of the additional metadata fields. The filename of the baseline file for each testing category will be listed in the respective section of the documentation for that category.

### Collected Energy Usage Metrics
The energy usage metrics that can be gathered by the current version of the `Energy Meter API` can be seen detailed in the table below. As support for additional energy meters is added, the range of available metrics that the API can gather may expand further. The `Joules` value is derived by the collector from `mWh` using the conversion $J = mWh \times 3.6$.

| **Metric**        | **Description**                                                                      |
|-------------------|--------------------------------------------------------------------------------------|
| Voltage (V)       | Voltage reading sampled from the energy meter.                                       |
| Current (A)       | Current reading sampled from the energy meter.                                       |
| Power (W)         | Instantaneous power reading sampled from the energy meter.                           |
| mWh               | Energy usage so far in milliwatt-hours during the test window.                       |
| mAh               | Charge usage so far in milliamp-hours during the test window.                        |
| Joules            | Derived energy usage in joules so far during the test window (`mWh * 3.6`).          |
| Elapsed Time (ms) | Current elapsed measurement time in milliseconds for the current test sample stream. |

In addition to the per-sample parsed CSV files, the parser also generates per-run condensed CSV files (`*_condensed.csv`).
These condensed files group rows by test metadata and apply metric aggregation as follows:

| **Metric Group** | **Input Metrics**                   | **Columns Produced in Condensed Output** |
|------------------|-------------------------------------|------------------------------------------|
| Poll metrics     | Voltage (V), Current (A), Power (W) | Min, Max, Avg, Std. Dev                  |
| Total metrics    | mWh, mAh, Joules, Elapsed Time (ms) | Total <Metric> (maximum observed value)  |
| Group metadata   | N/A                                 | Total Record Count                       |

If during the parsing process, the parser encounters a run where no energy usage data was collected, the blank line will be skipped and not included within the final record count.

### PQC Computational Energy Usage
The computational energy usage metrics measure the total energy consumed by the system during the execution of specific cryptographic operations for PQC algorithms. This is done by utilising the PQC KEM and digital signature implementations available from the Liboqs library. The energy usage collection tool runs the same cryptographic operations as the computational performance testing suite, but instead will perform energy measurement using connected energy meters. The collected energy usage data provides insight into the power efficiency of different PQC algorithms during their core operations.

Each cryptographic operation is ran for a user defined number of iterations and the energy usage data is collected during this period. The rate at which the energy meter is polled for data during this period is also user defined.

In addition to the standard energy usage metrics, the computational energy usage result files will also include the following metadata fields to provide context for the energy usage data:

| **Metadata Field** | **Description**                              |
|--------------------|----------------------------------------------|
| Algorithm Name     | The specific PQC algorithm being tested.     |
| Operation          | The cryptographic operation being performed. |

The baseline energy usage file for this testing category will be named:
`comp_energy_usage_baseline.csv`

### TLS Handshake Energy Usage
TLS handshake energy usage metrics measure the total energy consumed during the execution of TLS 1.3 handshakes using different PQC, Hybrid-PQC, and classical algorithm combinations. These measurements are obtained by executing the standard TLS handshake tests with energy monitoring enabled, allowing energy consumption data to be collected during the handshake operations. The resulting data provides insight into the power efficiency and practical implementation costs of different cryptographic algorithm combinations when deployed within real-world TLS 1.3 handshakes.

TLS handshake energy usage testing follows the same pattern as standard TLS handshake performance testing, with the exception that by default no handshake performance data is recorded. The user can choose to store the performance results when configuring the client machine. Testing is performed for both first use of a session ID and session ID reuse for each PQC/Hybrid-PQC signing-algorithm/KEM pairing and each classical signing-algorithm/key-exchange-group/ciphersuite combination. Energy usage data is collected during the handshakes for each scenario. For detailed information on the standard TLS handshake testing process, please refer to the [TLS Handshake Performance Metrics](./performance_metrics_guide.md#tls-handshake-testing) section of this document.

In addition to the standard energy usage metrics, the TLS handshake energy usage result files will also include the following metadata fields to provide context for the energy usage data.

For PQC and Hybrid-PQC results, the following metadata fields are included:

| **Metadata Field**   | **Description**                                                        |
|----------------------|------------------------------------------------------------------------|
| Signing Algorithm    | The specific digital signature algorithm used in the handshake.        |
| KEM Algorithm        | The specific KEM algorithm used in the handshake.                      |
| Session ID Reuse (*) | Indicates whether session ID reuse was enabled for the handshake test. |

For classical results, the following metadata fields are included:

| **Metadata Field**   | **Description**                                                        |
|----------------------|------------------------------------------------------------------------|
| Signing Algorithm    | The specific digital signature algorithm used in the handshake.        |
| Key Exchange Group   | The classical key-exchange group used in the handshake.                |
| Ciphersuite          | The TLS 1.3 ciphersuite used for the classical handshake test.         |
| Session ID Reuse (*) | Indicates whether session ID reuse was enabled for the handshake test. |

The baseline energy usage file for this testing category will be named:
`tls_handshake_energy_usage_baseline.csv`

### TLS Speed Energy Usage
TLS speed energy usage metrics evaluate the energy consumption of cryptographic operations for PQC, Hybrid-PQC, and classical algorithms within OpenSSL. The test performs individual operations using the OpenSSL command-line tools while energy monitoring is enabled. It measures key generation, encapsulation, and decapsulation for PQC/Hybrid-PQC KEMs; key generation, signing, and verification for PQC/Hybrid-PQC and classical signatures; and key generation and shared-secret derivation for classical key-exchange algorithms.

Because this test invokes OpenSSL operations directly rather than relying on the predefined `openssl speed` result categories, it can explicitly request RSA-PSS signing and verification. For its RSA results, the `RSA_*` categories use generic RSA keys and the `RSA-PSS_*` categories use RSA-PSS-restricted keys; both categories use PSS padding for the measured signing and verification operations.

Similar to computational energy usage testing, the TLS speed energy usage tests are performed by running the each algorithm's respective cryptographic operations for a user defined number of iterations while collecting energy usage data. The rate at which the energy meter is polled for data during this period is also user defined.

In addition to the standard energy usage metrics, the TLS speed energy usage result files will also include the following metadata fields to provide context for the energy usage data:

| **Metadata Field** | **Description**                                                       |
|--------------------|-----------------------------------------------------------------------|
| Algorithm Name     | The specific PQC, Hybrid-PQC, or classical algorithm being tested.    |
| Operation          | The cryptographic operation being performed.                          |

The baseline energy usage file for this testing category will be named:
`tls_speed_energy_usage_baseline.csv`

## Energy Usage Metrics Result Data Storage Structure
Both the un-parsed and parsed energy usage results data will be stored on the collector machine which polls the energy meter during testing rather than the device which performs the cryptographic operations. When using the automated collector and testing scripts provided by the project, the following directory structure will be used for storing the energy usage metrics data. If the energy usage collection tools are used outwith the context of the provided testing scripts, the way result data is stored will depend on how the respective programmes were configured during setup and execution.

**Energy Usage Metrics Data Storage:**

| **Testing Category** | **State** | **Description**                                                                                     | **Location** *(relative to `test_data/`)*                                                      |
|----------------------|-----------|-----------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Computational Energy | Un-parsed | Raw text files containing energy usage data for PQC cryptographic operations.                       | `up_results/energy_test_results/pqc_performance_energy_results/machine_x/`                     |
| Computational Energy | Parsed    | Processed per-run CSV result files, plus condensed per-run CSV summaries.                           | `results/energy_test_results/pqc_performance_energy_results/machine_x/`                        |
| TLS Handshake Energy | Un-parsed | Raw text files for each PQC/Hybrid SIG/KEM or classical signature/group/ciphersuite handshake test. | `up_results/energy_test_results/tls_handshake_energy_results/machine_x/`                       |
| TLS Handshake Energy | Parsed    | Processed per-run CSV result files grouped into classic, pqc, and hybrid_pqc, plus condensed files. | `results/energy_test_results/tls_handshake_energy_results/machine_x/{classic/pqc/hybrid_pqc}/` |
| TLS Speed Energy     | Un-parsed | Raw text files containing energy usage data for each algorithm and operation.                       | `up_results/energy_test_results/tls_speed_energy_results/machine_x/`                           |
| TLS Speed Energy     | Parsed    | Per-run PQC, Hybrid-PQC, and classical CSVs by algorithm type, plus condensed files.                | `results/energy_test_results/tls_speed_energy_results/machine_x/{pqc/hybrid/classic}/`         |

Where `machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be set for the results.

TLS speed energy parsing produces `pqc` and `hybrid_pqc` KEM/signature result files and `classic` signature/key-exchange result files. These are stored in the `pqc`, `hybrid`, and `classic` sub-directories, respectively. The filename format is `tls_speed_(algorithm-group)_(algorithm-type)_(run-number).csv`, with a matching `_condensed.csv` summary for each file. The baseline CSV remains directly under the machine directory.

## Useful External Documentation
- [Liboqs Webpage](https://openquantumsafe.org/liboqs/)
- [Liboqs GitHub Page](https://github.com/open-quantum-safe/liboqs)
- [Valgrind Massif Tool](http://valgrind.org/docs/manual/ms-manual.html)
- [OQS-Provider Webpage](https://openquantumsafe.org/applications/tls.html#oqs-openssl-provider)
- [OQS-Provider GitHub Page](https://github.com/open-quantum-safe/oqs-provider)
- [OpenSSL(4.0.1) Release](https://github.com/openssl/openssl/releases/tag/openssl-4.0.1)
- [OpenSSL(4.0.1) Documentation](https://docs.openssl.org/4.0/)