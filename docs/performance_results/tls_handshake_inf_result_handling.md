# TLS Handshake `inf` Result Handling
This document describes the occurrence of `inf` values in the TLS handshake benchmarking within PQC-LEO, explains why they occur, and outlines how they are handled in the framework.

## Cause and Occurrence
During development of the v0.5.0 release of PQC-LEO, it was identified that certain signature and KEM algorithm combinations may produce `inf` values for the **"Connections Per User Second"** metric during TLS handshake benchmarking when using shorter test durations. This behaviour is due to how this metric is calculated within the OpenSSL `speed` tool, where if no change in user CPU time is registered during testing, the resulting value is `inf`.

This behaviour is more likely to occur when the TLS handshake test duration is below 5 seconds. It is not tied to a specific signature/KEM combination and does not occur consistently across runs. However, it has only been observed in variants of `SPHINCS`, though not reliably for every variant or execution.

Further technical details, including the root cause within the dependency source code, are documented in the following discussion:

- [PR #82 Discussion Comment](https://github.com/crt26/PQC-LEO/pull/82#issuecomment-4040631744)

## Recommendation
To ensure consistent and complete average calculations, it is recommended to use TLS handshake test durations of **5 seconds or greater**. This reduces the likelihood of `inf` values occurring and ensures that all test runs can be included in average calculations. Please also review how performance metrics are structured to accommodate this behaviour, as described in the [Impact on Output Data](#impact-on-output-data) section.

## Mitigation in PQC-LEO
To handle this issue while maintaining flexibility within PQC-LEO, the following functionality was introduced in v0.5.0:

- A validation check during TLS performance test configuration to warn users when selected test durations may lead to `inf` results
- Enhanced result parsing logic that detects occurrences of `inf` values and excludes affected runs from average calculations, while tracking the number of valid runs used

### Configuration-Time Validation
To warn users when a TLS handshake test duration may produce `inf` results, additional checks have been added to the `pqc_tls_performance_test` script.

During configuration, the `pqc_tls_performance_test.sh` script checks whether the selected TLS handshake test duration is below 5 seconds. If the set testing duration is shorter than 5 seconds, a warning is shown explaining that shorter test lengths may produce `inf` values for the **"Connections Per User Second"** metric when testing certain signature/KEM combinations.

After the warning is displayed, the following actions can be taken:

- Continue with the selected test duration despite the possibility of `inf` results occurring in TLS handshake testing
- Choose to enter a new test duration

If the user opts to enter a new duration after the warning, the script will enforce a minimum TLS handshake test length of 5 seconds for the remainder of the configuration process.

### Handling During Result Parsing
When calculating average TLS handshake results, the Python parsing scripts will check for the presence of `inf` values in the data collected across all runs for each signature/KEM combination.

If a run contains an `inf` value in any metric, that entire run is excluded from the average calculation. Only runs with valid numerical results are used when computing the final averages.

To maintain transparency, the number of runs used in the average is recorded alongside the results. This allows users to clearly identify when fewer runs were included due to invalid data.

This approach ensures that invalid data does not skew results, while still allowing meaningful averages to be calculated from the remaining valid runs.

However, despite this handling, it is still advisable to use test durations that minimise the likelihood of `inf` values occurring, so that averages can be calculated using all test runs.

## Impact on Output Data
To support this behaviour, averaged TLS Handshake result CSV files include additional columns indicating the number of runs used in each calculation. As a result, these CSVs have slightly different column headers compared to those generated for individual runs.

Please keep this difference in mind when developing scripts that interact with PQC-LEO result files.

Additional information on how parsed results are structured can be found in the following documentation:

- [Performance Metrics Guide](../performance_results/performance_metrics_guide.md)  
- [TLS Handshake Testing Section](../performance_results/performance_metrics_guide.md#tls-handshake-testing)