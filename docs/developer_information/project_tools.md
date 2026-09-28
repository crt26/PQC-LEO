# Project Tools Documentation <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides additional reference information on the source code files that are used to implement the various tools included within the PQC-LEO framework. This document is intended to be used as a reference guide for developers who are looking to understand the implementation details of the various tools included within the PQC-LEO framework, and to provide additional context and information on how these tools work and how they can be used.

This document does not provide detailed instructions on the usage of these tools, but rather serves as a set of overviews for each of the various source files, what command line arguments they accept, and what their purpose is within the tools implementation. For detailed usage instructions of these tools, please refer to the relevant documentation files that will be linked within each section of this document.

The included tools within PQC-LEO are as follows:
- Computational Energy Usage Testing Tool
- Energy Usage Collector Tools

### Contents <!-- omit from toc -->
- [Computational Energy Usage Testing Tool](#computational-energy-usage-testing-tool)
  - [comp\_energy\_tester.h](#comp_energy_testerh)
  - [comp\_energy\_tester.c](#comp_energy_testerc)
- [Energy Usage Collector Tool](#energy-usage-collector-tool)
  - [Tool Component Overviews](#tool-component-overviews)
  - [meter\_api](#meter_api)
  - [controller\_api](#controller_api)
  - [controller\_utils](#controller_utils)
  - [network\_controller](#network_controller)
  - [serial\_controller](#serial_controller)
  - [collector](#collector)
  - [control\_sender](#control_sender)

## Computational Energy Usage Testing Tool
The computational energy usage testing tool provides a means of evaluating the energy usage of the cryptographic operations of the various PQC algorithms supported by the PQC-LEO framework. It utilises the PQC implementations available within the Liboqs library and the controller API functions included within the `energy usage collector` tool to perform the energy usage testing.

The tool consists of the following source files:
- comp_energy_tester.h
- comp_energy_tester.c

To be compiled it relies on the following libraries:
- liboqs
- libcontroller.a
- libmeter.a

Where libcontroller.a and libmeter.a are the libraries produced by the `energy usage collector` tool.

Detailed usage instructions for the computational energy usage testing tool can be found in the following documentation files:

[Computational Energy Usage Testing Guide](../project_tools_guides/comp_energy_tester_usage_guide.md)

### comp_energy_tester.h
This header file contains the function declarations for the computational energy usage testing tool, as well as the necessary includes and definitions required for the implementation of the tool. The functions declared are only used within the comp_energy_tester.c source file, and are not intended to be used outside of the context of the computational energy usage testing tool.

### comp_energy_tester.c
This program implements the PQC-LEO computational energy usage benchmarking tool. It configures the control channel to the energy collector, gathers test run options from the user, performs a baseline measurement, and executes KEM and signature benchmarking loops across the available liboqs algorithms. During execution, it coordinates GETREADY, START, and STOP control messaging for each test phase and manages Liboqs initialisation and shutdown.

The program accepts the following command line arguments:

| **Argument Shorthand** | **Argument Longhand**            | **Functionality**                                                                |
|------------------------|----------------------------------|----------------------------------------------------------------------------------|
| `-c`                   | `--use-custom-net-control-ports` | Use custom network control ports for energy testing control signalling           |
| `-s`                   | `--skip-welcome-message`         | Skip the welcome message on startup (useful for automated calling of the script) |
| `-h`                   | `--help`                         | Display the help message                                                         |

## Energy Usage Collector Tool
The energy usage collector tools provide the necessary tools to perform energy usage testing for a variety of different testing scenarios. While the primary purpose of the tool is to perform energy usage testing for the various PQC algorithms supported by the PQC-LEO framework, it can be used to perform energy usage testing for any arbitrary testing scenario by utilising the controller and meter API functions included within the tool to coordinate the energy usage testing process and collect the results.

Detailed usage instructions for the energy usage collector tools can be found in the following documentation files:

[Energy Usage Testing Guide](../project_tools_guides/energy_collector_usage_guide.md)

### Tool Component Overviews
The tool provides the following components:
- Energy Meter API
- Test Controller API
- Test orchestration scripts

#### Energy Meter API
The energy meter API provides an abstraction layer for interacting with the various supported energy meters within the PQC-LEO framework. It provides a common set of functions for interacting with the energy meters, regardless of the specific meter being used. This allows for a consistent interface for collecting energy usage data across different testing scenarios and different energy meters. It's source files fall under the `_meter_interfaces` directory which includes the main meter API sources files alongside the various source files for the specific meter implementations.

This component consists of the following source files:
- meter_api.h
- meter_api.c
- energy meter specific source files

#### Test Controller API
The test controller API provides a set of functions for sending and receiving control messages to coordinate the energy usage testing process. It provides functions for sending messages to signal the start and stop of tests, which include the necessary metadata to identify the test parameters for the energy usage data being collected. This facilitates the coordination between the collector device, which is responsible for using the meter API to poll the energy meter for data and the testing device, which is responsible for executing the tests and sending the necessary control messages to signal the start and stop of tests.

The flexibility provided by the test controller API allows for it to be used in a variety of different testing scenarios, as it can be used to coordinate any arbitrary testing process by sending the necessary control messages at the appropriate times during the testing process.

This component consists of the following source files:
- controller_api.h
- controller_api.c
- controller_utils.h
- controller_utils.c
- network_controller.h
- network_controller.c
- serial_controller.h
- serial_controller.c

#### Test Orchestration Scripts
The test orchestration scripts are a set of scripts that utilise the meter API and controller API to perform energy usage testing for various different testing scenarios. These scripts provide the necessary logic to collect the energy usage data for the specific testing scenario, and to coordinate the testing process by sending the necessary control messages at the appropriate times during the testing process.

This component consists of the following source files:
- collector.h
- collector.c
- control_sender.h
- control_sender.c

Whilst the `collector` program is more focused on the specific energy usage data collection feature of PQC-LEO, the `control_sender` program is more focused on providing a flexible tool for sending control messages to target collector machine, allowing for it be used in a variety of different testing scenarios outside of the provided energy usage testing scripts through the use of various command line arguments to specify the control message parameters and the target collector machine.

### meter_api
The meter API provides an abstraction layer for interacting with the various supported energy meters within the PQC-LEO framework. It provides a common set of functions for interacting with the energy meters, regardless of the specific meter being used. This allows for a consistent interface for collecting energy usage data across different testing scenarios and different energy meters. The API includes functions for initialising the energy meter, sending control commands to the energy meter, polling live readings from the energy meter, and closing the connection to the energy meter. For details on the API's usage, please refer to the [Meter API Guide](./energy_collector_APIs/meter_api_guide.md). For details on adding new energy meter backends, please refer to the [Integrating New Energy Meters](./energy_collector_APIs/integrating_new_energy_meters.md) guide.

### controller_api
The test controller API provides an abstraction layer for sending and receiving test control messages using either serial or network communication methods. It provides a consistent interface for test control, allowing for the same set of functions to be used for sending control messages regardless of the specific communication method being used. The API includes functions for sending messages to signal the start and stop of tests, which include the necessary metadata to identify the test parameters for the energy usage data being collected. For detailed usage instructions for the test controller API, please refer to the [Controller API Guide](./energy_collector_APIs/controller_api_guide.md).

### controller_utils
The `controller_utils` source file provides a set of utility functions that can be used when performing test control messaging. The functions provided include serial port discovery and selection, control message tokenisation, GETREADY payload extraction/validation, and a control handler that sends and receives messages using the configured controller backend. These utility functions are used in conjunction with the test controller API to provide the necessary functionality for sending and receiving control messages. For detailed usage instructions for the utility functions provided in the `controller_utils` source files, please refer to [Controller API Guide](./energy_collector_APIs/controller_api_guide.md).

### network_controller
The `network_controller` source file provides an implementation of the test controller API using network communication methods. It includes functions for initialising the network controller, sending control messages using network communication, and closing the connection to the network controller. It currently supports the use of UDP sockets for control signalling, with TCP socket support planned for future development. For detailed usage instructions for the network controller implementation of the test controller API, please refer to [Controller API Guide](./energy_collector_APIs/controller_api_guide.md).

### serial_controller
The `serial_controller` source file provides an implementation of the test controller API using serial communication methods. It includes functions for initialising the serial controller, sending control messages using serial communication, and closing the connection to the serial controller. The serial controller implementation may require additional setup and configuration on the system so that it can properly communicate with the target collector machine. For detailed usage instructions for the serial controller implementation of the test controller API, please refer to [Controller API Guide](./energy_collector_APIs/controller_api_guide.md).

### collector
The `collector` program is a test orchestration script that utilises the meter API and controller API to perform energy usage testing for various different testing scenarios. This program is ran on the designated collector machine, which is responsible for collecting the energy usage data using the meter API and coordinating the testing process by receiving the necessary control messages from the testing machine using the controller API. This program can be ran in isolation, but a `energy_metric_collector.sh` script is included with PQC-LEO that provides a easy to use interface for automating energy usage testing using the `collector` program.

The script accepts the following command line arguments:

| **Argument Shorthand** | **Argument Longhand**            | **Functionality**                                                                            |
|------------------------|----------------------------------|----------------------------------------------------------------------------------------------|
| `-d`                   | `--results-dir`                  | Specify the directory to store results in (if not provided, will prompt for it during setup) |
| `-s`                   | `--skip-welcome-message`         | Skip the welcome message on startup (useful for automated calling of the script)             |
| `-c`                   | `--use-custom-net-control-ports` | Use custom network control ports for energy testing control signalling                       |
| `-h`                   | `--help`                         | Display the help message                                                                     |

### control_sender
The `control_sender` program is a test orchestration script that utilises the controller API to send control messages to a target collector machine. This program is intended to provide a flexible tool for sending control messages to target collector machine, allowing for it be used in a variety of different testing scenarios outside of the provided energy usage testing scripts through the use of various command line arguments to specify the control message parameters and the target collector machine. The program can be used to send control messages to signal the start and stop of tests, which include the necessary metadata to identify the test parameters for the energy usage data being collected. For detailed usage instructions for the `control_sender` program, please refer to [Energy Usage Testing Guide](../project_tools_guides/energy_collector_usage_guide.md).

The script accepts the following command line arguments:

| **Argument Shorthand** | **Argument Longhand**   | **Functionality**                                                                      |
|------------------------|-------------------------|----------------------------------------------------------------------------------------|
| `-s`                   | `--start-test`          | Send a test start message.                                                             |
| `-t`                   | `--stop-test`           | Send a test stop message.                                                              |
| `-e`                   | `--end-testing`         | Send a message to end the entire testing session.                                      |
| `-T`                   | `--test-type `          | Specify the test type (e.g., performance, tls_handshake, etc.)                         |
| `-A`                   | `--test-algs `          | String to specify the algorithm/s that are being tested.                               |
| `-R`                   | `--run-num `            | Specify the run number for the test (positive integer).                                |
| `-P`                   | `--polling-rate `       | Specify the polling rate in milliseconds (a value of 0 means no delays between polls). |
| `-Z`                   | `--controller-method `  | Specify the control signalling method to use (serial or network).                      |
| `-C`                   | `--com-port `           | Specify the COM port to use for serial communication.                                  |
| `-L`                   | `--local-ip `           | Specify the local IP address for network communication.                                |
| `-Q`                   | `--remote-ip `          | Specify the remote IP address for network communication.                               |
| `-N`                   | `--custom-local-port `  | Specify a custom local port for network communication.                                 |
| `-J`                   | `--custom-remote-port ` | Specify a custom remote port for network communication.                                |
| `-h`                   | `--help`                | Display the help message.                                                              |
