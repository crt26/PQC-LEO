# Energy Collector Tool Usage Guide <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides a comprehensive guide to the energy usage collector tools included within PQC-LEO. It covers the components that make up the tools, their build requirements, and how to configure and use the `collector` and `control_sender` programs to coordinate tests, collect energy meter readings, and store the resulting data. Although these tools primarily support PQC-LEO's energy usage testing scripts, they can also be used independently for other energy measurement scenarios.

If you prefer to use the automated energy usage testing scripts provided by PQC-LEO, please refer to the [Automated PQC Energy Usage Testing Guide](../testing_tools_usage/pqc_energy_usage_testing.md) for information on setting up the testing environment and running the supplied automation scripts.

This guide focuses on using the supplied programs. For developer information on the underlying APIs and integrating additional energy meter support, please refer to the following guides:

- [Controller API Guide](../developer_information/energy_collector_APIs/controller_api_guide.md)
- [Meter API Guide](../developer_information/energy_collector_APIs/meter_api_guide.md)
- [Integrating New Energy Meters](../developer_information/energy_collector_APIs/integrating_new_energy_meters.md)

### Contents <!-- omit from toc -->
- [Tool Description](#tool-description)
- [Building the Energy Usage Collector Tools](#building-the-energy-usage-collector-tools)
- [Collector Program Usage](#collector-program-usage)
  - [Program Overview](#program-overview)
  - [Running the Collector Program](#running-the-collector-program)
  - [Configuring the Collector Program](#configuring-the-collector-program)
  - [Collector Program Testing Process](#collector-program-testing-process)
  - [Results Output](#results-output)
- [Control Sender Program Usage](#control-sender-program-usage)
  - [Program Overview](#program-overview-1)
  - [Running the Control Sender Program](#running-the-control-sender-program)
  - [Control Sender Program Command Line Arguments](#control-sender-program-command-line-arguments)

## Tool Description
The energy usage collector tools provide the necessary tools to perform energy usage testing for a variety of different testing scenarios. While the primary purpose of the tool is to perform energy usage testing for the various PQC algorithms supported by the PQC-LEO framework, it can be used to perform energy usage testing for any arbitrary testing scenario by utilising the controller and meter API functions included within the tool to coordinate the energy usage testing process and collect the results.

The energy usage collector tools are currently **only supported on Linux systems**. Future development will include support for other operating systems.

Whilst PQC-LEO provides automation scripts to utilise the energy usage collector tools for performing energy usage testing, the tools can also be used independently of the provided automation scripts to perform energy usage testing for any arbitrary testing scenario.

The energy usage collector tools consist of the following components:
- Energy Meter API
- Test Controller API
- Test orchestration scripts

#### Energy Meter API:
The energy meter API provides an abstraction layer for interacting with the various supported energy meters within the PQC-LEO framework. It provides a common set of functions for interacting with the energy meters, regardless of the specific meter being used. This allows for a consistent interface for collecting energy usage data across different testing scenarios and different energy meters. Its source files fall under the `_meter_interfaces` directory which includes the main meter API source files alongside the various source files for the specific meter implementations.

For detailed information on the energy meter API functions, please refer to the [Meter API Guide](../developer_information/energy_collector_APIs/meter_api_guide.md) for detailed information on the meter API functions and their usage.

For information on the supported energy meters within the PQC-LEO framework, please refer to the [Supported Energy Meters](../energy_meter_guides/energy_meter_support.md) document for detailed information on the supported energy meters and their respective functionality. Furthermore, if you wish to integrate a new energy meter into the PQC-LEO framework, please refer to the [Integrating New Energy Meters](../developer_information/energy_collector_APIs/integrating_new_energy_meters.md) document for detailed information on how to integrate a new energy meter into the PQC-LEO framework.

#### Test Controller API:
The test controller API provides a set of functions for sending and receiving control messages to coordinate the energy usage testing process. It provides functions for sending messages to signal the start and stop of tests, which include the necessary metadata to identify the test parameters for the energy usage data being collected. This facilitates the coordination between the collector device, which is responsible for using the meter API to poll the energy meter for data and the testing device, which is responsible for executing the tests and sending the necessary control messages to signal the start and stop of tests.

The flexibility provided by the test controller API allows for it to be used in a variety of different testing scenarios, as it can be used to coordinate any arbitrary testing process by sending the necessary control messages at the appropriate times during the testing process.

For detailed information on the test controller API functions, please refer to the [Controller API Guide](../developer_information/energy_collector_APIs/controller_api_guide.md) for detailed information on the controller API functions and their usage.

#### Test Orchestration Scripts:
The test orchestration scripts are a set of scripts that utilise the meter API and controller API to perform energy usage testing for various different testing scenarios. These scripts provide the necessary logic to collect the energy usage data for the specific testing scenario, and to coordinate the testing process by sending the necessary control messages at the appropriate times during the testing process.

The energy usage collector tools currently include the following test orchestration programs:

- collector
- control_sender

## Building the Energy Usage Collector Tools
The energy usage collector tools are built by default when energy usage testing is enabled in the PQC-LEO setup script. However, if you wish to setup the tools independently of the setup script, you can build the tools manually from the `tools/energy_collector` directory.

Unlike the computational energy usage testing tool, the energy usage collector tools do not rely on any other components of the PQC-LEO framework to be built, with the exception of a path to an OpenSSL installation.

The energy usage collector tools rely on the following libraries:

- OpenSSL Version 3.3.0 or higher
- libserialport (`libserialport-dev`)

The tools can be built by running the makefile located in the `tools/energy_collector` directory. The main makefile in `tools` builds both energy tools and also requires Liboqs. Both makefiles use the system OpenSSL by default; see [OpenSSL Compatibility for Energy Tools](../developer_information/project_dependencies.md#openssl-compatibility-for-energy-tools) for the requirements.

To build with the system's OpenSSL installation, you can run the following command from the PQC-LEO project root directory:

```bash
cd tools/energy_collector
make
```

To specify a custom OpenSSL installation path, you can run the following command from the PQC-LEO project root directory:

```bash
cd tools/energy_collector
make OPENSSL_PATH=/path/to/openssl
```

Use an absolute path for `OPENSSL_PATH`; for the PQC-LEO build, this is the project's `lib/openssl_4.0.2` directory.

The compiled binaries will then be located in the `tools/energy_collector/build/bin` directory.

In addition to the compiled tools, the build process will create library object files for the meter API and controller API, which can be found in the `tools/energy_collector/build/lib` directory. These library object files can be used to link against when using the APIs provided by the energy usage collector tools in external tools, such as the computational energy usage testing tool.

Before running `collector` or `control_sender` manually with the project or custom OpenSSL, add its library directory to `LD_LIBRARY_PATH` in the same shell:

```bash
export LD_LIBRARY_PATH="/path/to/openssl/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

Replace `/path/to/openssl` with the selected installation's absolute path. Use `lib` instead of `lib64` if `libcrypto.so` is only present there. The automated `energy_metric_collector.sh` script configures this path for the project build automatically.

## Collector Program Usage

### Program Overview
The `collector` program is a test orchestration script that utilises the meter API and controller API to perform energy usage testing for various different testing scenarios. This program is run on the designated collector machine, which is responsible for collecting the energy usage data using the meter API and coordinating the testing process by receiving the necessary control messages from the testing machine using the controller API. This program can be run in isolation, but an `energy_metric_collector.sh` script is included with PQC-LEO that provides an easy to use interface for automating energy usage testing using the `collector` program.

### Running the Collector Program
This program is primarily designed to work with the supported energy meters and the control_sender test orchestration program included within the energy usage collector tools. When running the script manually, first please refer to the specific documentation for the energy meter you are using to setup the energy meter and collection machine appropriately. This information can be found in the [Supported Energy Meters](../energy_meter_guides/energy_meter_support.md) document for detailed information on the supported energy meters and their respective functionality. Furthermore, if you wish to integrate a new energy meter into the PQC-LEO framework, please refer to the [Integrating New Energy Meters](../developer_information/energy_collector_APIs/integrating_new_energy_meters.md) document for detailed information on how to integrate a new energy meter into the PQC-LEO framework.

Once the collection environment is setup, you can run the `collector` program by running the following command from wherever the compiled binaries are located:

```bash
./collector
```

### Configuring the Collector Program
Once started, the program will then prompt the user to configure the collection parameters, which include the following:

- The control signalling method to be used (serial or network)
- Configuration of the selected control signalling method
- The energy meter type to use for collection
- The serial port to be used for communicating with the energy meter
- The directory to store the collected energy usage data

The available energy meter options are generated from the collector's supported meter mapping and shown as numbered entries during setup. The selected option is then mapped to the corresponding internal meter backend type used by the Meter API.

The program also allows for some of these parameters to be configured by passing command line arguments when launching the program. This is primarily useful when the program is being launched by the provided `energy_metric_collector.sh` script, but can also be used when launching the program manually. The accepted command line arguments are as follows:

| **Argument Shorthand** | **Argument Longhand**            | **Functionality**                                                                            |
|------------------------|----------------------------------|----------------------------------------------------------------------------------------------|
| `-d`                   | `--results-dir`                  | Specify the directory to store results in (if not provided, will prompt for it during setup) |
| `-s`                   | `--skip-welcome-message`         | Skip the welcome message on startup (useful for automated calling of the script)             |
| `-c`                   | `--use-custom-net-control-ports` | Use custom network control ports for energy testing control signalling                       |
| `-h`                   | `--help`                         | Display the help message                                                                     |

### Collector Program Testing Process
The collector program will then wait for incoming control messages from the testing machine, which include the following:

- `GETREADY` - This message includes the GETREADY command with additional test parameter metadata, which is used by the collector program to create the result file, and prepare the collector for the upcoming test. This message is sent by the testing machine before the test begins. Once this is complete the collector program sends a READY message back to the testing machine to signal that it is ready for the test to begin.

- `START` - This message includes the START command, which signals the collector program to start collecting energy usage metrics for the test. It will continue to poll the energy meter for data (at the specified polling rate included with the GETREADY message) until a STOP message is received.

- `STOP` - This message includes the STOP command, which signals the collector program to stop collecting energy usage metrics for the test. Once this message is received, the collector program will finalise the result file for the test that was just completed, and prepare for the next incoming GETREADY message for the next test.

- `END` - This message includes the END command, which signals the collector program that there are no more tests to be performed, and that it can finalise all result files and end the program.

These messages are automatically handled by the `control_sender` program, but can be sent to the collector program manually as long as it is done using the correct formatting specified in the controller API documentation.

### Results Output
Results from the testing process will be stored in the specified results directory, with each test having its own respective result file. The result files are formatted in a specific way to facilitate easy parsing of the energy usage data, with all necessary test parameter metadata included in the filename to allow for easy identification of the test parameters for each result file.

## Control Sender Program Usage

### Program Overview
The `control_sender` program is a test orchestration program that utilises the controller API to send control messages to a target collector machine. This program is intended to provide a flexible tool for sending control messages to target collector machine, allowing for it to be used in a variety of different testing scenarios outside of the provided energy usage testing scripts through the use of various command line arguments to specify the control message parameters and the target collector machine. The program can be used to send control messages to signal the start and stop of tests, which include the necessary metadata to identify the test parameters for the energy usage data being collected.

### Running the Control Sender Program
This program is primarily designed to work with the `collector` test orchestration program included within the energy usage collector tools. The `control_sender` program works by passing all the relevant command line arguments when calling it, which specify the following:

- Which control signal method to be used
- The configuration parameters for the selected control signal method
- The type of control message to be sent (GETREADY, START, STOP, END)
- The test parameters to be included in the control messages being sent
- Any additional configuration parameters

Further details on this can be found in the next section.

An example of how the `control_sender` program can be called to send a GETREADY message, wait for READY, and then send START to a collector machine is as follows:

```bash
./control_sender -s \
  -T "tls_operations_sig_verify" \
  -A "ML-DSA-44" \
  -R "1" \
  -P "100" \
  -Z "serial" \
  -C "/dev/ttyUSB0"
```

### Control Sender Program Command Line Arguments
The `control_sender` program accepts the following command line arguments, which configure how the program behaves and what control messages it sends to the target collector machine:

| **Argument Shorthand** | **Argument Longhand**   | **Functionality**                                                                      |
|------------------------|-------------------------|----------------------------------------------------------------------------------------|
| `-s`                   | `--start-test`          | Send a test start message.                                                             |
| `-t`                   | `--stop-test`           | Send a test stop message.                                                              |
| `-e`                   | `--end-testing`         | Send a message to end the entire testing session.                                      |
| `-T`                   | `--test-type `          | Specify the test type (e.g., performance, tls_handshake, etc.)                         |
| `-A`                   | `--test-algs `          | Algorithm metadata. TLS handshakes use `sig@kem` or `sig@group@ciphersuite`.           |
| `-R`                   | `--run-num `            | Specify the run number for the test (positive integer).                                |
| `-P`                   | `--polling-rate `       | Specify the polling rate in milliseconds (a value of 0 means no delays between polls). |
| `-Z`                   | `--controller-method `  | Specify the control signalling method to use (serial or network).                      |
| `-S`                   | `--serial-port `        | Specify the serial port to use for serial communication.                               |
| `-L`                   | `--local-ip `           | Specify the local IP address for network communication.                                |
| `-Q`                   | `--remote-ip `          | Specify the remote IP address for network communication.                               |
| `-N`                   | `--custom-local-port `  | Specify a custom local port for network communication.                                 |
| `-J`                   | `--custom-remote-port ` | Specify a custom remote port for network communication.                                |
| `-h`                   | `--help`                | Display the help message.                                                              |

For TLS handshake energy collection, quote the `--test-algs` value and use one of the following formats:

- PQC/Hybrid-PQC: `"signing-alg@kem-alg"`
- Classical: `"signing-alg@key-exchange-group@ciphersuite"`

The collector preserves this metadata in the result filename so the energy parsing script can distinguish PQC/Hybrid-PQC results from classical results and populate the appropriate CSV columns.

For all other testing types, the `--test-algs` value can be any string that represents the algorithm being tested.
