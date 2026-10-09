# TLS Handshake `inf` Result Handling
This document describes the occurrence of `inf` values in the TLS handshake benchmarking within PQC-LEO, explains why they occur, and outlines how they are handled in the framework.

## Cause and Occurrence
During development of the v0.5.0 release of PQC-LEO, it was identified that certain signature and KEM algorithm combinations may produce `inf` values for the **"Connections Per User Second"** metric during TLS handshake benchmarking when using shorter test durations. This behaviour is due to how this metric is calculated within the OpenSSL `s_time` tool, where if no change in user CPU time is registered during testing, the resulting value is `inf`.

This behaviour is more likely to occur when the TLS handshake test duration is below 5 seconds. It is not tied to a specific algorithm combination and does not occur consistently across runs. It was initially observed in variants of `SPHINCS`, though not reliably for every variant or execution. During routine functionality testing, the same issue was also identified in classical TLS handshake results following the additional algorithm support introduced in [PR #124](https://github.com/crt26/PQC-LEO/pull/124).

Further technical details, including the root cause within the dependency source code, are documented in the following discussion:

- [PR #82 Discussion Comment](https://github.com/crt26/PQC-LEO/pull/82#issuecomment-4040631744)

## Recommendation
To improve consistency of average calculations, it is recommended to use TLS handshake test durations of **5 seconds or greater**. This reduces the likelihood of `inf` values occurring but does not guarantee that all test runs can be included in average calculations. Please also review how performance metrics are structured to accommodate this behaviour, as described in the [Impact on Output Data](#impact-on-output-data) section.

## Mitigation in PQC-LEO
To handle this issue while maintaining flexibility within PQC-LEO, the following functionality is provided:

- A validation check during TLS performance test configuration to warn users when selected test durations may lead to `inf` results
- Enhanced result parsing logic that detects occurrences of `inf` values and excludes affected rows from average calculations, while tracking the number of valid runs used

The warning during test configuration and result parsing handling for PQC and Hybrid-PQC algorithms were introduced in v0.5.0. The result parsing handling has since been extended to classical TLS handshake results in v0.6.1.

### Configuration-Time Validation
To warn users when a TLS handshake test duration may produce `inf` results, additional checks have been added to the `pqc_tls_performance_test` script.

During configuration, the `pqc_tls_performance_test.sh` script checks whether the selected TLS handshake test duration is below 5 seconds. If the set testing duration is shorter than 5 seconds, a warning is shown explaining that shorter test lengths may produce `inf` values for the **"Connections Per User Second"** metric.

After the warning is displayed, the following actions can be taken:

- Continue with the selected test duration despite the possibility of `inf` results occurring in TLS handshake testing
- Choose to enter a new test duration

If the user opts to enter a new duration after the warning, the script will enforce a minimum TLS handshake test length of 5 seconds for the remainder of the configuration process.

### Handling During Result Parsing
When calculating average TLS handshake results for PQC, Hybrid-PQC, and classical algorithms, the Python parsing scripts check for `inf` values across all test runs. This is performed for each signature/KEM combination for PQC and Hybrid-PQC results, and each signing algorithm, key exchange group, and ciphersuite combination for classical results. If a row contains an `inf` value in any metric, the entire row is excluded from the average calculation. Session ID first-use and reuse results are handled independently for each algorithm combination.

If no valid runs remain for an average calculation, the metric fields are written as `N/A` and **Runs used for Average** is set to 0. **Total Runs** still records the total number of test runs performed.

To maintain transparency, the number of runs used in the average is recorded alongside the results. This allows users to clearly identify when fewer runs were included due to invalid data.

This approach ensures that invalid data does not skew results, while still allowing meaningful averages to be calculated from the remaining valid runs.

However, despite this handling, it is still advisable to use test durations that minimise the likelihood of `inf` values occurring, so that averages can be calculated using all test runs.

## Impact on Output Data
To support this behaviour, averaged TLS handshake result CSV files for PQC, Hybrid-PQC, and classical algorithms include **Runs used for Average** and **Total Runs** columns. These indicate the number of valid runs used in each calculation and the total number of test runs performed. As a result, these CSVs have slightly different column headers compared to those generated for individual runs.

Please keep this difference in mind when developing scripts that interact with PQC-LEO result files.

Additional information on how parsed results are structured can be found in the following documentation:

- [Performance Metrics Guide](../performance_results/performance_metrics_guide.md)  
- [TLS Handshake Testing Section](../performance_results/performance_metrics_guide.md#tls-handshake-testing)
