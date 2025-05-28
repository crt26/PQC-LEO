# Automated PQC TLS Performance Benchmarking Tool Usage Guide <!-- omit from toc -->

## Overview <!-- omit from toc -->
This tool provides automated benchmarking for PQC-enabled TLS 1.3 handshakes and cryptographic operation performance in OpenSSL 3.5.0 using the OQS-Provider library. It tests TLS handshakes with various combinations of Post-Quantum Cryptography (PQC) and Hybrid-PQC cipher suites and measures the performance of these algorithms when integrated into OpenSSL. In addition to PQC-focused benchmarks, the tool also evaluates classic cryptographic algorithms, which can serve as a baseline for comparing PQC-based results. Testing can be conducted on a single machine (localhost) or across two networked machines, using a physical or virtual connection.

The relevant PQC TLS Performance testing scripts can be found in the `scripts/test-scripts` directory from the project's root.

### Contents <!-- omit from toc -->
- [Supported Hardware](#supported-hardware)
- [Supported PQC Algorithms](#supported-pqc-algorithms)
- [Preparing the Testing Environment](#preparing-the-testing-environment)
  - [Control Ports and Firewall Setup for Testing](#control-ports-and-firewall-setup-for-testing)
  - [Generating Required Certificates and Private Keys](#generating-required-certificates-and-private-keys)
- [Performing PQC TLS Performance Testing](#performing-pqc-tls-performance-testing)
  - [Testing Tool Execution](#testing-tool-execution)
  - [Testing Options](#testing-options)
  - [Single Machine Testing](#single-machine-testing)
  - [Separate Server and Client Machine Testing](#separate-server-and-client-machine-testing)
- [Outputted Results](#outputted-results)
- [Advanced Testing Customisation](#advanced-testing-customisation)
  - [Customising Testing Suite TCP Ports](#customising-testing-suite-tcp-ports)
  - [Adjusting Control Signalling](#adjusting-control-signalling)
- [Useful External Documentation](#useful-external-documentation)

## Supported Hardware
The automated testing tool is currently only supported on the following devices:

- x86 Linux Machines using a Debian-based operating system
- ARM Linux devices using a 64-bit Debian based Operating System

## Supported PQC Algorithms
Whilst this project provides support for all PQC algorithms included in its dependency libraries for TLS testing, due to various incompatibles and dependency limitations, there a several PQC algorithms which are excluded. Whilst the number of algorithms not included are a small amount, it is important to consider this limitation when using the tool.

Additional information on the excluded algorithms can be found in the OpenSSL and OQS-Provider subsections in the following project documentation:

[Supported Algorithms](../supported-algorithms.md)

## Preparing the Testing Environment
Before running any tests, it is crucial to ensure the necessary setup steps for your planned testing environment (single-machine/two-machine configuration) have been performed. This includes allowing required ports through your firewall and generating test server certificates and private-keys.

### Control Ports and Firewall Setup for Testing
The benchmarking tool uses several TCP ports to coordinate communication between the server and client machines and to run TLS handshake tests. This applies to both single-machine and two-machine setups, so the necessary ports must be open and accessible. For TLS handshake testing to function correctly, the system must allow communication on these ports. These requirements apply to both local (localhost) and remote configurations.

Please make sure your firewall allows traffic on the following ports:

| **Port Usage**            | **Default TCP Port** |
|---------------------------|----------------------|
| Server Control TCP Port   | 25000                |
| Client Control TCP Port   | 25001                |
| OpenSSL S_Server TCP Port | 4433                 |

If the default TCP ports are unsuitable for your environment, please see the [Advanced Testing Customisation](#advanced-testing-customisation) section for further instructions on configuring custom TCP ports.

### Generating Required Certificates and Private Keys
To perform the TLS handshake performance tests, the server certificate and private-key files must first be generated. The generated keys and certificates will be saved to the `test-data/keys` directory in the project root. This can be done by executing the following command from within the `scripts/testing-scripts` directory:

```
./oqsprovider-generate-keys.sh
```

**If you're testing across two machines, copy the entire keys directory to the second machine before proceeding.**

## Performing PQC TLS Performance Testing
Once the testing environment has been properly configured, it is now possible to begin the automated PQC TLS performance testing.

### Testing Tool Execution
To start the automated testing tool, open a terminal in the `scripts/testing-scripts` directory and run the following command:

```
./full-oqs-provider-test.sh
```

Upon executing the script, the testing tool will prompt you to enter the parameters for the test. Different setup techniques and options will be required depending on the testing scenario (single-machine/two-machine).

**It is also recommended** to refer to the Testing Options section below before beginning testing to ensure all configurations are correct.

### Testing Options
The testing tool will prompt you to enter the parameters for the test. These parameters include:

- Machine type (server or client)
- Machine Comparison Option
- Machine Results ID (if comparison option selected)
- Number of test runs to be performed
- Duration of each TLS handshake tests (if machine is client) **†**
- Duration of TLS speed tests (if machine is client) **††**
- IP address of the other machine (use 127.0.0.1 for single-machine testing)

**†** Defines the duration (in seconds) the OpenSSL `s_time` tool will use for each handshake test window. The client will attempt as many TLS handshakes as possible for each algorithm combination during this period.

**††** Defines the duration (in seconds) for benchmarking individual cryptographic operations (e.g., signing or key encapsulation) using the OpenSSL `s_speed` tool.

### Single Machine Testing
If running the full test locally (single-machine), perform the following steps after generating the required certificates:

#### Server Setup:
1. Run the `full-oqs-provider-test.sh` script

2. Select server when prompted
  
3. Enter the requested test parameters

4. Use 127.0.0.1 as the IP address for the other machine

5. Once the server setup is complete, leave the terminal open and proceed to the client setup

#### Client Setup:
1. In a separate terminal session, run the `full-oqs-provider-test.sh` script again.

2. Select client when prompted

3. Enter the requested test parameters
  
4. Use 127.0.0.1 as the IP address for the other machine

5. The test will begin, and results will be stored automatically

### Separate Server and Client Machine Testing
When two machines are used for testing that are connected over a physical/virtual network, one machine will be configured as the server and the other as the client. Before starting, please ensure that both machines have the same server certificates and private keys stored in the `test-data/keys` directory.

#### Server Machine Setup:
1. On the server machine, run the `full-oqs-provider-test.sh` script

2. Select the server and enter the test parameters when prompted

3. Use the IP address of the client machine when prompted

4. Now begin the setup of the client machine before the testing can begin

#### Client Setup:
1. On the client machine, run the `full-oqs-provider-test.sh` script

2. Select the client and enter the test parameters

3. Use the IP address of the server machine

4. Begin testing and allow the script to complete

## Outputted Results
After testing completes, raw performance results are saved to the following directory:

`test-data/up-results/oqs-provider/machine-x`

Where `machine-x` refers to the assigned Machine-ID. If no ID was specified, the default ID of 1 is used.

By default, the OQS-Provider testing script will automatically trigger the parsing process. It supplies the required parameters (Machine-ID and total test runs) to the parsing tool, which then generates structured CSV outputs for analysis.

These parsed results are saved in:

`test-data/results/oqs-provider/machine-x`

> **Note:** When using multiple machines for testing, the results will only be stored on the client machine, not the server machine.

To disable automatic parsing and preserve only the raw results, pass the `--disable-result-parsing` flag when launching the test script:

```
./full-oqs-provider-test.sh --disable-result-parsing
```

For complete details on parsing functionality and a breakdown of the collected PQC TLS performance metrics, refer to the following documentation:

- [Parsing Performance Results Usage Guide](../performance-results/parsing-scripts-usage-guide.md)
- [Performance Metrics Guide](../performance-results/performance-metrics-guide.md)

## Advanced Testing Customisation
The automated PQC TLS benchmarking tool allows users to customise specific parameters used in the testing automation process. This is particularly useful when adapting the tool to restricted networks, virtual machines, or specific performance testing conditions.

The currently supported testing customisation options are as follows:

- TCP port configuration 
- Control Signal Behaviour

### Customising Testing Suite TCP Ports
If the benchmark scripts' default TCP ports are unsuitable for your environment, custom ports can be specified when launching the test script. This can be done independently for the server and client by passing the following flags:

| **Flag**                       | **Description**                            |
|--------------------------------|--------------------------------------------|
| `--server-control-port=<PORT>` | Set the server control port   (1024-65535) |
| `--client-control-port=<PORT>` | Set the client control port   (1024-65535) |
| `--s-server-port=<PORT>`       | Set the OpenSSL S_Server port (1024-65535) |

**When using custom TCP ports**, please ensure the same values are provided to both the server and client instances. Otherwise, the testing will fail.

### Adjusting Control Signalling
By default, the tool uses a 0.25 second delay when sending control signals between the server and client instances. This is to avoid timing issues during the control signal exchange, which can cause testing to fail.

If the default control signalling timing behaviour is unsuitable for your testing environment, you can customise the control signal sleep time or disable it entirely when executing the `full-oqs-provider-test.sh` script. You can do this by including the following flags:

| **Flag**                      | **Description**                                          |
|-------------------------------|----------------------------------------------------------|
| `--control-sleep-time=<TIME>` | Set the control sleep time in seconds (integer or float) |
| `--disable-control-sleep`     | Disable the control signal sleep time                    |

**Please note** that the `--control-sleep-time` flag cannot be used with the `--disable-control-sleep` flag.

## Useful External Documentation
- [OQS-Provider Webpage](https://openquantumsafe.org/applications/tls.html#oqs-openssl-provider)
- [OQS-Provider GitHub Page](https://github.com/open-quantum-safe/oqs-provider)
- [Latest OQS-Provider Release Notes](https://github.com/open-quantum-safe/oqs-provider/blob/main/RELEASE.md)
- [OQS Benchmarking Webpage](https://openquantumsafe.org/benchmarking/)
- [OQS Profiling Project](https://openquantumsafe.org/benchmarking/)
- [OpenSSL(3.5.0) Documentation](https://docs.openssl.org/3.5/)