# Energy Collector Controller API Guide <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides a developer reference for the controller API included within the PQC-LEO energy collector tools. The API provides a unified interface for exchanging control messages between testing and collection devices using either serial or network communication, allowing applications to coordinate when energy measurement data collection should start and stop.

The guide details the controller API data structures and functions, the serial and network controller backends, and the supporting utility functions used to configure controllers, format and parse control messages, and manage test metadata. It also provides usage examples for initialising a controller, sending and receiving messages, and closing the selected communication backend. For instructions on building and running the supplied `collector` and `control_sender` programs, refer to the [Energy Collector Tool Usage Guide](../../project_tools_guides/energy_collector_usage_guide.md).

### Contents <!-- omit from toc -->
- [API Description](#api-description)
- [Controller API Data Structures](#controller-api-data-structures)
  - [TestController Data Structure](#testcontroller-data-structure)
- [Controller API Functions](#controller-api-functions)
  - [controller\_init() Function](#controller_init-function)
  - [controller\_send() Function](#controller_send-function)
  - [controller\_receive() Function](#controller_receive-function)
  - [controller\_close() Function](#controller_close-function)
- [Controller API Function Usage](#controller-api-function-usage)
  - [Configure and Initialise Controller Instance](#configure-and-initialise-controller-instance)
  - [Sending Control Signal Messages](#sending-control-signal-messages)
  - [Receiving Control Signal Messages](#receiving-control-signal-messages)
  - [Closing the Controller Instance](#closing-the-controller-instance)
- [Network Controller Backend](#network-controller-backend)
  - [Network Controller Data Structures](#network-controller-data-structures)
  - [Network Controller Functions](#network-controller-functions)
- [Serial Controller Backend](#serial-controller-backend)
  - [Serial Controller Data Structures](#serial-controller-data-structures)
  - [Serial Controller Functions](#serial-controller-functions)
- [Controller Utils Data Structures](#controller-utils-data-structures)
  - [TestParams Data Structure](#testparams-data-structure)
- [Controller Utils Functions](#controller-utils-functions)
  - [list\_com\_ports() Function](#list_com_ports-function)
  - [get\_ip\_address() Function](#get_ip_address-function)
  - [check\_port\_availability() Function](#check_port_availability-function)
  - [get\_port\_number() Function](#get_port_number-function)
  - [message\_parser() Function](#message_parser-function)
  - [get\_ready\_formatter() Function](#get_ready_formatter-function)
  - [control\_handler() Function](#control_handler-function)
- [Controller Utils Function Usage](#controller-utils-function-usage)
  - [list\_com\_ports() Function Usage](#list_com_ports-function-usage)
  - [get\_ip\_address() Function Usage](#get_ip_address-function-usage)
  - [check\_port\_availability() Function Usage](#check_port_availability-function-usage)
  - [get\_port\_number() Function Usage](#get_port_number-function-usage)
  - [message\_parser() Function Usage](#message_parser-function-usage)
  - [get\_ready\_formatter() Function Usage](#get_ready_formatter-function-usage)
  - [control\_handler() Function Usage](#control_handler-function-usage)

## API Description
The controller API provides an abstraction layer for controlling the energy usage collector tool and coordinating the collection of energy usage metrics from the energy meter. This abstraction layer provides a set of unified functions for the network and serial control signalling method backends that are supported by the energy usage collector tool. The controller API functions can be used to configure the control signalling method, send control signals to the energy usage collector tool, and receive responses from the energy usage collector tool.

The following library file is produced when the energy collector tools are built, which contains the controller API functions:

- libcontroller.a

It consists of the following header files which contain the function prototypes for the controller API functions:

- controller_api.h
- controller_utils.h

As part of the `controller_api.h` header file, a `network_controller.h` and `serial_controller.h` header files are included which contain the function prototypes for the network and serial control signalling method backends respectively. These header files are included in the `controller_api.h` header file to provide a unified interface for the controller API functions, regardless of the control signalling method that is being used.

## Controller API Data Structures
The following are the main data structures that are used by the controller API functions:

- TestController

### TestController Data Structure
Stores controller configuration and backend instances for control signalling.

```c
typedef struct {
    char *control_type;
    SerialController serial_controller;
    NetworkController network_controller;
} TestController;
```

- `char *control_type`: Selected communication method (`"serial"` or `"network"`).
- `SerialController serial_controller`: Serial controller instance and configuration.
- `NetworkController network_controller`: Network controller instance and configuration.

The SerialController and NetworkController data structures are defined in the `serial_controller.h` and `network_controller.h` header files respectively, and are used to store the configuration and state of the serial and network control signalling method backends.

## Controller API Functions
The following are the main controller API functions that can be used to control and coordinate the collection of energy usage metrics from the energy meter. These functions are defined in the `controller_api.h` header file and are implemented in the `controller_api.c` source file.

- controller_init()
- controller_send()
- controller_receive()
- controller_close()

### controller_init() Function
Function for initialising the controller instance based on the specified control type. It will call the relevant initialisation function for the specified control type and return any errors.

```c
int controller_init(TestController *controller);
```

Parameters:
- `TestController *controller`: Pointer to a TestController data structure containing the configuration for the selected control signalling method.

Returns:
- `0` on success
- `-1` on failure

When calling this function, the `TestController` data structure must be provided with the appropriate configuration for the selected control signalling method. The function will then initialise the appropriate backend and return a status code indicating success or failure.

### controller_send() Function
Function for sending control signal messages using the controller instance based on the specified control type. It will call the relevant sending function for the specified control type and return any errors.

```c
int controller_send(TestController *controller, char *message);
```
Parameters:
- `TestController *controller`: Pointer to a TestController data structure containing the configuration for the selected control signalling method.

- `char *message`: Pointer to a string containing the control signal message to be sent.

Returns:
- `0` on success
- `-1` on failure

### controller_receive() Function
Function for receiving control signal messages using the controller instance based on the specified control type. It will call the relevant receiving function for the specified control type and return any errors.

```c
int controller_receive(TestController *controller, char *message, size_t message_size);
```

Parameters:
- `TestController *controller`: Pointer to a TestController data structure containing the configuration for the selected control signalling method.

- `char *message`: Pointer to a string buffer where the received control signal message will be stored.

- `size_t message_size`: Size of the message buffer.

Returns:
- `0` on success
- `-1` on failure

### controller_close() Function
Function for closing the controller instance based on the specified control type. It will call the relevant closing function for the specified control type and return any errors.

```c
int controller_close(TestController *controller);
```

Parameters:
- `TestController *controller`: Pointer to a TestController data structure containing the configuration for the selected control signalling method.

Returns:
- `0` on success
- `-1` on failure

## Controller API Function Usage
The controller API functions can be used to control and coordinate the collection of energy usage metrics from the energy meter. The following is an example of how to use the controller API functions to initialise a controller instance, send a control signal message, receive a response, and close the controller instance.

### Configure and Initialise Controller Instance

#### Serial Control Signalling Method:
For using a serial control signalling method, an example of initialising a controller instance with the appropriate configuration is shown below. The `TestController` data structure is defined and configured with the appropriate settings for the serial control signalling method, and then the `controller_init()` function is called to initialise the controller instance:

```c
#include "controller_api.h"

// Define an instance of the TestController data structure
TestController controller;

// Set control type to serial and configure serial controller settings
controller.control_type = "serial";
controller.serial_controller.control_port_name = "/dev/ttyUSB0";
controller.serial_controller.baudrate = 115200;
controller.serial_controller.data_bits = 8;
controller.serial_controller.parity = 0;
controller.serial_controller.stop_bits = 1;
controller.serial_controller.flow_control = 0;

// Initialise the controller instance
int ret = controller_init(&controller);
```

Please refer to the [Serial Controller Data Structures](#serial-controller-data-structures) section for more information on the serial controller configuration settings.

#### Network Control Signalling Method:
For using a network control signalling method, an example of initialising a controller instance with the appropriate configuration is shown below. The `TestController` data structure is defined and configured with the appropriate settings for the network control signalling method, and then the `controller_init()` function is called to initialise the controller instance:

```c
#include "controller_api.h"

// Define an instance of the TestController data structure
TestController controller;

// Set control type to network and configure network controller settings
controller.control_type = "network";
controller.network_controller.tcp_socket = -1;
controller.network_controller.udp_socket = -1;
controller.network_controller.local_port = 12345;
controller.network_controller.remote_port = 54321;
controller.network_controller.net_protocol = "UDP";
controller.network_controller.local_address = "192.168.1.10";
controller.network_controller.remote_address = "192.168.1.20";

// Initialise the controller instance
int ret = controller_init(&controller);
```

Please refer to the [Network Controller Data Structures](#network-controller-data-structures) section for more information on the network controller configuration settings.

### Sending Control Signal Messages
Once the controller instance has been initialised, control signal messages can be sent using the `controller_send()` function. The following is an example of how to send a control signal message using the controller instance:

```c
char message[] = "READY";
int ret = controller_send(&controller, message);
```

### Receiving Control Signal Messages
Control signal messages can be received using the `controller_receive()` function. The following is an example of how to receive a control signal message using the controller instance:

```c
char msg_buffer[512];
int ret = controller_receive(&controller, msg_buffer, sizeof(msg_buffer));
```

### Closing the Controller Instance
Once the controller instance is no longer needed, it can be closed using the `controller_close()` function. The following is an example of how to close the controller instance:

```c
int ret = controller_close(&controller);
```

## Network Controller Backend
As part of the controller API, the network controller functions handle the transmission and receiving of control signal messages over a network connection. These functions are defined in the `network_controller.h` header file and implemented in the `network_controller.c` source file. Based on the selected control type in the `TestController` data structure, the controller API calls the relevant network controller functions.

These functions are not accessed directly through the controller API, but are instead called by the controller API functions based on the selected control type in the `TestController` data structure. The following information is provided for reference purposes only, and is not intended to be used directly by the user.

>**Notice:** TCP mode is currently not supported by the energy collector tools. The network controller functions currently only support UDP connections, with future development to include TCP support.

### Network Controller Data Structures
The following are the main data structures that are used by the network controller functions:

- NetworkController

#### NetworkController Data Structure
This data structure is defined in the `network_controller.h` header file and is used to store the configuration and state of the network control signalling method backend. It is stored within the `TestController` data structure and is used by the controller API functions to send and receive control signal messages over a network connection. When defining the `TestController` data structure, the `NetworkController` data structure must be included and configured with the appropriate settings for the network control signalling method.

```c
typedef struct {
    int tcp_socket;
    int udp_socket;
    int local_port;
    int remote_port;
    const char* net_protocol;
    const char* local_address;
    const char* remote_address;
    struct sockaddr_in local_addr;
    struct sockaddr_in remote_addr;
} NetworkController;
```

- `int tcp_socket`: TCP socket descriptor (used when TCP mode is enabled).
- `int udp_socket`: UDP socket descriptor (used when UDP mode is enabled).
- `int local_port`: Local port used for bind/listen operations.
- `int remote_port`: Remote port used for outbound messages.
- `const char* net_protocol`: Selected protocol string ("TCP" or "UDP").
- `const char* local_address`: Local IPv4 address string.
- `const char* remote_address`: Remote IPv4 address string.
- `struct sockaddr_in local_addr`: Parsed local socket address structure.
- `struct sockaddr_in remote_addr`: Parsed remote socket address structure.

### Network Controller Functions
The following are the main network controller functions that can be used to send and receive control signal messages over a network connection. The following information is provided for reference purposes only, and is not intended to be used directly by the user.

#### network_controller_init() Function
Initialises the network controller with the configured socket settings.

```c
int network_controller_init(NetworkController *network_controller);
```

Parameters:
- `NetworkController *network_controller`: Pointer to a NetworkController data structure containing the configuration for the network control signalling method.

Returns:
- `0` on success
- `-1` on failure

#### network_controller_receiver() Function
Receives a control message from the configured network socket.

```c
int network_controller_receiver(NetworkController *network_controller, char *message, size_t message_size);
```

Parameters:
- `NetworkController *network_controller`: Pointer to a NetworkController data structure containing the configuration for the network control signalling method.
- `char *message`: Output buffer for the received message.
- `size_t message_size`: Size of `message` in bytes.

Returns:
- `0` on success
- `-1` if receive fails

#### network_controller_send() Function
Sends a control message to the configured remote device

```c
int network_controller_send(NetworkController *network_controller, char *message);
```

parameters:
- `NetworkController *network_controller`: Pointer to a NetworkController data structure containing the configuration for the network control signalling method.
- `char *message`: Message to be sent.

Returns:
- `0` on success
- `-1` if send fails

#### network_controller_close() Function
Closes the network controller and releases socket resources.

```c
int network_controller_close(NetworkController *network_controller);
```

parameters:
- `NetworkController *network_controller`: Pointer to a NetworkController data structure containing the configuration for the network control signalling method.

Returns:
- `0` on success
- `-1` on failure

## Serial Controller Backend
As part of the controller API, the serial controller functions handle the transmission and receiving of control signal messages over a serial connection. These functions are defined in the `serial_controller.h` header file and implemented in the `serial_controller.c` source file. Based on the selected control type in the `TestController` data structure, the controller API calls the relevant serial controller functions.

These functions are not accessed directly through the controller API, but are instead called by the controller API functions based on the selected control type in the `TestController` data structure. The following information is provided for reference purposes only, and is not intended to be used directly by the user.

### Serial Controller Data Structures
The following are the main data structures that are used by the serial controller functions:

- SerialController

#### SerialController Data Structure
This data structure is defined in the `serial_controller.h` header file and is used to store the configuration and state of the serial control signalling method backend. It is stored within the `TestController` data structure and is used by the controller API functions to send and receive control signal messages over a serial connection. When defining the `TestController` data structure, the `SerialController` data structure must be included and configured with the appropriate settings for the serial control signalling method.

```c
typedef struct {
    const char *control_port_name;
    struct sp_port* control_port;
    int baudrate;
    int data_bits;
    int parity;
    int stop_bits;
    int flow_control;
} SerialController;
```

- `const char *control_port_name`: Serial port identifier.
- `struct sp_port* control_port`: Open libserialport handle for the configured control port.
- `int baudrate`: Serial baud rate used for communication.
- `int data_bits`: Number of data bits per frame.
- `int parity`: Parity mode used by the serial interface.
- `int stop_bits`: Number of stop bits per frame.
- `int flow_control`: Flow control mode used by the serial interface.

### Serial Controller Functions
The following are the main serial controller functions that can be used to send and receive control signal messages over a serial connection. The following information is provided for reference purposes only, and is not intended to be used directly by the user.

#### serial_controller_init() Function
Initialises the serial controller with the configured serial port settings.

```c
int serial_controller_init(SerialController *serial_controller);
```

Parameters:
- `SerialController *serial_controller`: Pointer to a SerialController data structure containing the configuration for the serial control signalling method.

Returns:
- `0` on success
- `-1` on failure

#### serial_controller_receiver() Function
Receives a control message from the configured serial port. Reads bytes until a newline or carriage return is received. The delimiter is not included in the copied output string.

```c
int serial_controller_receiver(SerialController *serial_controller, char *message, size_t message_size);
```

Parameters:
- `SerialController *serial_controller`: Pointer to a SerialController data structure containing the configuration for the serial control signalling method.
- `char *message`: Output buffer for the received message.
- `size_t message_size`: Size of `message` in bytes.

Returns:
- `0` on success
- `-1` if receive fails

#### serial_controller_send() Function
Sends a control message through the configured serial port. The payload is transmitted exactly as provided; no newline or carriage return terminator is appended by this function.

```c
int serial_controller_send(SerialController *serial_controller, char *message);
```

Parameters:
- `SerialController *serial_controller`: Pointer to a SerialController data structure containing the configuration for the serial control signalling method.
- `char *message`: Message to be sent.

Returns:
- `0` on success
- `-1` if send fails

#### serial_controller_close() Function
Closes the serial controller and releases serial port resources.

```c
int serial_controller_close(SerialController *serial_controller);
```

Parameters:
- `SerialController *serial_controller`: Pointer to a SerialController data structure containing the configuration for the serial control signalling method.

Returns:
- `0` on success
- `-1` if close fails

## Controller Utils Data Structures
The following are the main data structures that are used by the controller utils functions:

- TestParams

### TestParams Data Structure
The TestParams data structure holds information on the control method being used and various testing parameter metadata that can be included within control signal messages sent to the energy usage collector tool. It is defined in the `controller_utils.h` header file and is used by various functions to easily store and pass the testing parameter metadata between functions. When defining the TestParams data structure, the appropriate fields must be included and configured with the values for the testing parameters being used.

```c
typedef struct {
    char *control_method;
    int control_type;
    char *test_type;
    const char *test_algs;
    int total_runs;
    int run_num;
    int iterations;
    float polling_rate;
} TestParams;
```

- `char *control_method`: Control communication method ("serial" or "network").
- `int control_type`: Numeric control message type identifier used by internal logic.
- `char *test_type`: Test category/name.
- `const char *test_algs`: Tested algorithm metadata. TLS handshakes use `signing-alg@kem-alg` for PQC/Hybrid-PQC or `signing-alg@key-exchange-group@ciphersuite` for classical configurations.
- `int total_runs`: Total number of runs configured for the test.
- `int run_num`: Run number for the current test.
- `int iterations`: Number of iterations configured for the run.
- `float polling_rate`: Energy polling rate in miliseconds.

## Controller Utils Functions
The following are various utility functions that are included within the `libcontroller.a` library and are defined in the `controller_utils.h` header file. These functions are used to assist with various tasks related to the controller API functions, such as parsing control signal messages, validating control signal messages, and converting between different data types. The following utility functions are available:

- list_com_ports()
- get_ip_address()
- check_port_availability()
- get_port_number()
- message_parser()
- get_ready_formatter()
- control_handler()

### list_com_ports() Function
Helper function for listing the available serial COM ports on the system. It uses the libserialport library to enumerate the available serial ports and print their names to the console. The user is then able to select which COM port to use for communication. The function returns a char array containing the selected port name.

```c
char* list_com_ports();
```

Returns:
- `char*`: Pointer to the selected COM port string, or NULL on failure.

### get_ip_address() Function
Helper function for prompting the user for an IP address and validating it. Once the input is validated, it is stored in the provided buffer.

```c
void get_ip_address(char *ip_address, size_t ip_address_len);
```

Parameters:
- `char *ip_address`: Output buffer where the validated IPv4 address string will be written.
- `size_t ip_address_len`: Length of the `ip_address` buffer in bytes.

### check_port_availability() Function
Helper function for checking the availability of a specified network port. It attempts to bind a test socket to the specified port and returns a status code indicating whether the port is available or not.

```c
int check_port_availability(int port_number, const char *protocol);
```

Parameters:
- `int port_number`: Port number to test for availability (1-65535).
- `const char *protocol`: Name of the protocol to check the port for ("TCP" or "UDP").

Returns:
- `0` if bind succeeded (port available)
- `-1` on failure

### get_port_number() Function
Function for prompting the user to enter a network port number and validating that it is within the valid range (1-65535). The function will continue to prompt until a valid port number is entered.

```c
void get_port_number(int *port_number);
```

Parameters:
- `int *port_number`: Pointer to an integer where the validated port number will be stored

### message_parser() Function
Function for parsing a provided message from the control port. It will extract any parameters from the message and store them in the provided message_elements array. Primarily used for extracting the testing parameters from the GETREADY message, it may be used for other message types given it follows the correct formatting.

```c
int message_parser(char *message, char *command, char **message_elements, size_t message_elements_size);
```

Parameters:
- `char *message`: Input message buffer to parse.
- `char *command`: String value for the expected command to be contained in the message.
- `char **message_elements`: Output array for parsed message tokens.
- `size_t message_elements_size`: Capacity of the `message_elements` array.

Returns:
- `0` on success
- `-1` on parse/validation failure

### get_ready_formatter() Function
Helper function for formatting the GETREADY message to be sent to the collector machine. It will format the message with the test parameters and return it in the provided buffer.

```c
int get_ready_formatter(TestParams *test_params, char *get_ready_message, size_t message_size);
```

Parameters:
- `TestParams *test_params`: Pointer to a TestParams data structure containing the test parameters to be included in the GETREADY message.
- `char *get_ready_message`: Output buffer where the formatted GETREADY message will be written.
- `size_t message_size`: Size of the `get_ready_message` buffer in bytes.

### control_handler() Function
Function for handling the control actions based on the control type specified in the TestParams struct. It will send the appropriate command to the collector machine based on the control type and parameters. This function will call the relevant controller API functions to send and receive control signal messages based on the selected control type in the TestParams struct. It will also handle any errors that may occur during the control signal message handling process.

It is intended to be ran primarily on the testing device, as the function flow is designed to send, wait, and receive control signal message as if it is a client device.

```c
int control_handler(TestController *test_controller, TestParams *test_params);
```

Parameters:
- `TestController *test_controller`: Pointer to a TestController data structure containing the configuration for the selected control signalling method.
- `TestParams *test_params`: Pointer to a TestParams data structure containing the test parameters to be sent to the collector machine for test configuration.

Returns:
- `0` on success
- `-1` on command/response handling failure

## Controller Utils Function Usage
The controller utils functions can be used to assist with various tasks related to the controller API functions, such as parsing control signal messages, validating control signal messages, and converting between different data types.

### list_com_ports() Function Usage
The `list_com_ports()` function can be used to list the available serial COM ports on the system and allow the user to select which COM port to use from that list. The returned COM port name can then be used to configure the serial controller instance for communication with the energy usage collector tool.

Example usage of the `list_com_ports()` function is shown below:
```c
#include "controller_api.h"
#include "controller_utils.h"

// List available COM ports and get the selected port name
char *selected_port = list_com_ports();

// Configure the serial controller instance with the selected COM port name
controller.serial_controller.control_port_name = selected_port;
```

### get_ip_address() Function Usage
The `get_ip_address()` function can be used to prompt the user for an IP address and validate it. Once the input is validated, it is stored in the provided buffer.

Example usage of the `get_ip_address()` function is shown below:
```c
#include "controller_utils.h"

// Define a buffer to hold the validated IP address
char ip_address[16];

// Prompt the user for an IP address and validate it
get_ip_address(ip_address, sizeof(ip_address));
```

### check_port_availability() Function Usage
The `check_port_availability()` function can be used to check the availability of a specified network port. It attempts to bind a test socket to the specified port and returns a status code indicating whether the port is available or not.

Example Usage of the `check_port_availability()` function is shown below:
```c
#include "controller_utils.h"

// Define the port number and protocol to check
int local_port_number = 12345;

// Check if the specified port is available for use on the system
int ret = check_port_availability(local_port_number, "UDP");

if (ret == 0) {
    printf("Port %d is available for use.\n", local_port_number);
} else {
    printf("Port %d is not available for use.\n", local_port_number);
}
```

### get_port_number() Function Usage
The `get_port_number()` function can be used to prompt the user to enter a network port number and validate that it is within the valid range (1-65535). The function will continue to prompt until a valid port number is entered.

Example usage of the `get_port_number()` function is shown below:
```c
#include "controller_utils.h"

// Define a variable to hold the validated port number
int port_number;

// Prompt the user for a port number and validate it
get_port_number(&port_number);
```

Example usage of the `get_port_number()` function with the [check_port_availability()](#check_port_availability-function) function is shown below:
```c
#include "controller_utils.h"

// Define a variable to store the local port number
int local_port_number;

// Prompt the user for a port number and validate it
get_port_number(&local_port_number);

// Check if the specified port is available for use on the system
int ret = check_port_availability(local_port_number, "UDP");

if (ret == 0) {
    printf("Port %d is available for use.\n", local_port_number);
} else {
    printf("Port %d is not available for use.\n", local_port_number);
}
```

### message_parser() Function Usage
The `message_parser()` function can be used to parse a provided message from the control port. It will extract any parameters from the message and store them in the provided message_elements array. Primarily used for extracting the testing parameters from the GETREADY message, it may be used for other message types given it follows the correct formatting.

Example usage of the `message_parser()` function is shown below:
```c
#include "controller_api.h"
#include "controller_utils.h"

// Define a buffer to hold the received message
char received_message[512];

// Wait for a GETREADY message to be received from the control port
int ret = controller_receive(&controller, received_message, sizeof(received_message));

// Define an array to hold the parsed message elements
char *message_elements[10];
size_t array_size = sizeof(message_elements);

// Parse the received message and extract the parameters
ret = message_parser(received_message, "GETREADY", message_elements, array_size);
```

### get_ready_formatter() Function Usage
The `get_ready_formatter()` function can be used to format the GETREADY message to be sent to the collector machine. It will format the message with the test parameters and return it in the provided buffer.

Example usage of the `get_ready_formatter()` function is shown below:
```c
#include "controller_api.h"
#include "controller_utils.h"

// Define a TestParams data structure with the test parameters
TestParams test_params;
test_params.control_method = "serial";
test_params.control_type = 1;
test_params.test_type = "tls_handshake";
test_params.test_algs = "ed25519@x25519@TLS_AES_128_GCM_SHA256";
test_params.total_runs = 5;
test_params.run_num = 1;
test_params.iterations = 100;
test_params.polling_rate = 100.0;

// Define a buffer to hold the formatted GETREADY message
char get_ready_message[512];
size_t message_size = sizeof(get_ready_message);

// Format the GETREADY message with the test parameters
int ret = get_ready_formatter(&test_params, get_ready_message, message_size);

// Send the formatted GETREADY message to the collector machine
ret = controller_send(&controller, get_ready_message);
```

### control_handler() Function Usage
The `control_handler()` function can be used to handle the control actions based on the control type specified in the TestParams struct. It will send the appropriate command to the collector machine based on the control type and parameters. This function will call the relevant controller API functions to send and receive control signal messages based on the selected control type in the TestParams struct. It will also handle any errors that may occur during the control signal message handling process.

This function is intended to be ran primarily on the testing device, as the function flow is designed to send, wait, and receive control signal message as if it is a client device.

Example usage of the `control_handler()` function is shown below:
```c
#include "controller_api.h"
#include "controller_utils.h"

// Define a TestParams data structure with the test parameters
TestParams test_params;
test_params.control_method = "serial";
test_params.control_type = 1;
test_params.test_type = "tls_speed";
test_params.test_algs = "ML-KEM-512";
test_params.total_runs = 5;
test_params.run_num = 1;
test_params.iterations = 100;
test_params.polling_rate = 100.0;

// Call the control_handler() function to handle the control actions
int ret = control_handler(&controller, &test_params);
```