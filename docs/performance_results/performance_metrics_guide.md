# PQC Performance Metrics & Results Storage Breakdown <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides a comprehensive guide to the PQC computational and TLS performance metrics collected by the project's automated benchmarking tools. It describes the types of metrics gathered and how raw test data is structured, parsed, and analysed across different environments using the provided testing and parsing scripts.

Specifically, it covers:

- An overview of the core cryptographic operations used in PQC digital signature schemes and Key Encapsulation Mechanisms (KEMs)

- A breakdown of the computational performance metrics gathered via Liboqs benchmarking tools, including how these results are stored and organised

- A description of TLS performance metrics obtained from testing OpenSSL’s native PQC support and OQS-Provider, along with their storage and processing structure

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
The TLS performance testing suite benchmarks PQC, Hybrid-PQC, and classical algorithm configurations available through both OpenSSL's native support and the OQS-Provider. As of OpenSSL 3.5.0, PQC algorithms are supported through both sources, and the suite is designed to evaluate performance consistently across the full range of available implementations. It measures performance within the TLS 1.3 handshake protocol and the execution speed of cryptographic operations directly through OpenSSL. This provides insight into how PQC schemes perform in real-world security protocol scenarios. Classical digital signature algorithms and ciphersuites are also tested to establish a performance baseline for comparison with PQC and Hybrid-PQC configurations.

As part of the automated TLS testing, two categories of evaluations are conducted:

- **TLS Handshake Testing** - This simulates full TLS 1.3 handshakes using OpenSSL’s `s_server` and `s_time` tools, evaluating both standard and session-resumed connections.

- **TLS Speed Testing** - This uses the OpenSSL `s_speed` tool to benchmark the algorithm's low-level operations, such as key generation, encapsulation, signing, and verification.

### TLS Handshake Testing
The TLS handshake performance tests measure how efficiently different PQC, Hybrid-PQC, and classical algorithm combinations perform during the TLS 1.3 handshake process. These tests are executed using OpenSSL's built-in benchmarking tools (`s_server` and `s_time`).

Each test performs the TLS handshake for a given digital signature and KEM algorithm combination (digital signature) as many times as possible for a set time window, both with and without session ID reuse, to evaluate the impact of session resumption on performance.

The table below describes the performance metrics gathered during this testing:

| **Metric**                                  | **Description**                                                                                                   |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| Connections in User Time                    | Number of successful TLS handshakes completed during CPU/user time. Reflects algorithm efficiency per CPU second. |
| Connections per User Second                 | Handshake rate per CPU second. Indicates performance under ideal CPU conditions.                                  |
| Real-Time                                   | Total wall clock time elapsed, including system I/O and process delays.                                           |
| Connections in Real Time                    | Number of handshakes completed in actual wall time. Useful for real-world performance assessment.                 |
| Connections per User Second (Session Reuse) | Handshake rate per CPU second with session ID reuse. Measures efficiency with session resumption.                 |
| Connections in Real Time (Session Reuse)    | Handshakes per real-world time with session reuse. Reflects practical performance with resumed sessions.          |

### TLS Speed Testing
TLS speed testing benchmarks the raw cryptographic performance of PQC, Hybrid-PQC, and classical algorithms when integrated into OpenSSL for both natively supported algorithms and those provided by the OQS-Provider library. This is done using the OpenSSL `s_speed` tool, which measures the execution time and throughput of cryptographic operations for each algorithm.

The primary objective of this test is to gather the base system performance of the schemes when integrated into the OpenSSL library. The results provide insight into the algorithm's standalone efficiency when running within OpenSSL, which can produce additional overhead compared to the performance tests provided by the computational performance testing suite.

#### Digital Signature Algorithm Metrics
The following table describes the metrics collected for digital signature algorithms during TLS speed testing:

| **Metric** | **Description**                                           |
|------------|-----------------------------------------------------------|
| keygen (s) | Average time in seconds to generate a signature key pair. |
| sign (s)   | Average time in seconds to perform a signing operation.   |
| verify (s) | Average time in seconds to verify a digital signature.    |
| keygens/s  | Number of key generation operations completed per second. |
| signs/s    | Number of signing operations completed per second.        |
| verifies/s | Number of verification operations completed per second.   |

#### KEM Algorithm Metrics
The following table describes the metrics collected for Key Encapsulation Mechanism (KEM) algorithms during TLS speed testing:

| **Metric** | **Description**                                                |
|------------|----------------------------------------------------------------|
| keygen (s) | Average time in seconds to generate a keypair.                 |
| encaps (s) | Average time in seconds to perform an encapsulation operation. |
| decaps (s) | Average time in seconds for decapsulation operation.           |
| keygens/s  | Number of key generation operations completed per second.      |
| encaps/s   | Number of encapsulation operations completed per second.       |
| decaps/s   | Number of decapsulation operations completed per second.       |

## TLS Performance Result Data Storage Structure
When running the TLS benchmarking script (`full_tls_test.sh`), all performance data is initially stored as unparsed output. This includes both handshake and speed test results. After testing, the parsing script processes this raw data into structured CSV files, including calculated averages across test runs.

| **Data Type**   | **State**     | **Description**                                                                             | **Location** *(relative to `test_data/`)*                                              |
|-----------------|---------------|---------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| TLS Handshake   | Un-parsed     | Raw `.txt` outputs from OpenSSL s_time tests for PQC, Hybrid-PQC, and Classic combinations. | `up_results/tls_performance/machine_x/handshake_results/{pqc/hybrid/classic}`          |
| TLS Handshake   | Parsed        | Per-run CSVs with extracted handshake metrics, by signature algorithm.                      | `results/tls_performance/machine_x/handshake_results/{pqc/hybrid/classic}/{signature}` |
| TLS Handshake   | Parsed (Base) | Combined CSVs aggregating all signature/KEM combinations for each run.                      | `results/tls_performance/machine_x/handshake_results/{pqc/hybrid}/base_results`        |
| TLS Speed       | Un-parsed     | Raw `.txt` outputs from OpenSSL speed tests for PQC and Hybrid-PQC algorithms.              | `up_results/tls_performance/machine_x/speed_results/{pqc/hybrid}`                      |
| TLS Speed       | Parsed        | Cleaned CSVs with cryptographic operation timings and throughput.                           | `results/tls_performance/machine_x/speed_results/`                                     |
| Parsed Averages | Parsed        | Averaged handshake and speed results across test runs.                                      | Stored alongside parsed result files in `results/tls_performance/machine_x/`           |

Where `machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be set for the results.

## Useful External Documentation
- [Liboqs Webpage](https://openquantumsafe.org/liboqs/)
- [Liboqs GitHub Page](https://github.com/open-quantum-safe/liboqs)
- [Valgrind Massif Tool](http://valgrind.org/docs/manual/ms-manual.html)
- [OQS-Provider Webpage](https://openquantumsafe.org/applications/tls.html#oqs-openssl-provider)
- [OQS-Provider GitHub Page](https://github.com/open-quantum-safe/oqs-provider)
- [OpenSSL(3.5.0) Release](https://github.com/openssl/openssl/releases/tag/openssl-3.5.0)
- [OpenSSL(3.5.0) Documentation](https://docs.openssl.org/3.5/)