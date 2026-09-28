/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This program implements the PQC-LEO control sender utility. It parses command-line
arguments for test control actions (START, STOP, END), validates required test and
controller parameters, configures the selected control interface (serial or network),
and transmits formatted control messages to the collector. It supports explicit test
metadata input (type, algorithms, run number, polling rate) and provides help/error
output for invalid or incomplete invocation.

*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include "control_sender.h"

//-------------------------------------------------------------------------------------------------------------------------------
void output_help() {
    /*  Function for outputting the help message for the contorl sender script. It will display the usage, options, and their 
        descriptions. After this, it will exit the program. */

    // Print the help message
    printf("Usage: control_sender [OPTIONS]\n");
    printf("Options:\n");
    printf("-s, --start-test                                Send a test start message\n");
    printf("-t, --stop-test                                 Send a test stop message\n");
    printf("-e, --end-testing                               Send a message to end the entire testing session\n");
    printf("-T, --test-type=<type>                          Specify the test type (e.g., performance, tls_handshake, etc.)\n");
    printf("-A, --test-algs=<algs>                          Specify algorithm metadata (e.g., kem or sig@kem or sig@group@ciphersuite)\n");
    printf("-R, --run-num=<number>                          Specify the run number for the test (positive integer)\n");
    printf("-P, --polling-rate=<rate>                       Specify the polling rate in milliseconds (a value of 0 means no delays between polls)\n");
    printf("-Z,  --controller-method=<serial|network>       Specify the control signalling method to use (serial or network)\n");
    printf("-C, --com-port=<port>                           Specify the COM port to use for serial communication\n");
    printf("-L, --local-ip=<ip>                             Specify the local IP address for network communication\n");
    printf("-Q, --remote-ip=<ip>                            Specify the remote IP address for network communication\n");
    printf("-N, --custom-local-port=<port>                  Specify a custom local port for network communication\n");
    printf("-J, --custom-remote-port=<port>                 Specify a custom remote port for network communication\n");
    printf("-h, --help                                      Display the help message and exit\n");

    // Exit the program
    exit(0);

}

//-------------------------------------------------------------------------------------------------------------------------------
int validate_ip(char *ip_address) {
    /* Helper function for validating the format of a provided IP address */

    // Validate the IP address format
    int octets[4];
    if (sscanf(ip_address,"%d.%d.%d.%d", &octets[0], &octets[1], &octets[2], &octets[3]) == 4) {

        // Check that each octet is within the valid range
        for (int i = 0; i < 4; i++) {
            if (octets[i] < 0 || octets[i] > 255) {
                return 0;
            }
        }

        return 1;

    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int parse_args(TestParams *test_params, ControllerInterfaces *controller_interfaces, int argc, char *argv[]) {
    /*  Function for parsing the command line arguments passed to the control sender script.It will populate the TestParams 
        structure with the relevant parameters and return an error code if any of the parameters are invalid. */

    // Define the getopt_long struct and options    
    struct option long_options[] = {
        {"start-test", no_argument, 0, 's'},
        {"stop-test", no_argument, 0, 't'},
        {"end-testing", no_argument, 0, 'e'},
        {"test-type", required_argument, 0, 'T'},
        {"test-algs", required_argument, 0, 'A'},
        {"run-num", required_argument, 0, 'R'},
        {"polling-rate", required_argument, 0, 'P'},
        {"com-port", required_argument, 0, 'C'},
        {"controller-method", required_argument, 0, 'Z'},
        {"local-ip", required_argument, 0, 'L'},
        {"remote-ip", required_argument, 0, 'Q'},
        {"custom-local-port", required_argument, 0, 'N'},
        {"custom-remote-port", required_argument, 0, 'J'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    // Declare the option and index variables
    int option;
    int option_index = 0;

    // Declare the local and remote custom port used flags
    int custom_local_port = 0;
    int custom_remote_port = 0;

    // Parse the command line arguments
    while ((option = getopt_long(argc, argv, "steT:A:R:P:C:Z:L:Q:N:J:h", long_options, &option_index)) != -1) {

        // Determine which option is being processed
        switch (option) {

            case 's':

                // Ensure that the control type has not already been set
                if (test_params->control_type != 0) {
                    fprintf(stderr, "[ERROR] - Cannot specify multiple control actions at once.\n");
                    output_help();
                    return -1;
                }

                // Set the control type and break
                test_params->control_type = 1;
                break;

            case 't':

                // Ensure that the control type has not already been set
                if (test_params->control_type != 0) {
                    fprintf(stderr, "[ERROR] - Cannot specify multiple control actions at once.\n");
                    output_help();
                    return -1;
                }

                // Set the control type and break
                test_params->control_type = 2;
                break;

            case 'e':
                
                // Ensure that the control type has not already been set
                if (test_params->control_type != 0) {
                    fprintf(stderr, "[ERROR] - Cannot specify multiple control actions at once.\n");
                    output_help();
                    return -1;
                }

                // Set the control type and break
                test_params->control_type = 3;
                break;
            
            case 'T':

                // Store the passed test type
                test_params->test_type = optarg;
                break;

            case 'A':

                // Store the passed test algorithms
                test_params->test_algs = optarg;
                break;

            case 'R':

                // Store the passed run number
                test_params->run_num = atoi(optarg);

                // Ensure that the run number is a valid integer and is greater than 0
                if (test_params->run_num <= 0) {
                    fprintf(stderr, "[ERROR] - Invalid run number. It must be a positive integer.\n");
                    output_help();
                    return -1;
                }
                break;

            case 'P':

                // Ensure that the polling rate argument is provided
                if (optarg == NULL) {
                    fprintf(stderr, "[ERROR] - Polling rate argument is missing.\n");
                    output_help();
                    return -1;
                }

                // Convert the polling rate to a float and ensure that it is a valid positive float
                float captured_polling_rate = atof(optarg);

                // Ensure that the polling rate is a valid positive float
                if (captured_polling_rate < 0.0f) {
                    fprintf(stderr, "[ERROR] - Invalid polling rate. It must be a positive float.\n");
                    output_help();
                    return -1;
                }

                // Store the passed polling rate
                test_params->polling_rate = captured_polling_rate;
                break;

            case 'C':

                // Store the user provided com port name
                controller_interfaces->com_port_name = optarg;

                // Ensure that the com port name is not empty
                if (controller_interfaces->com_port_name == NULL || strlen(controller_interfaces->com_port_name) == 0) {
                    fprintf(stderr, "[ERROR] - Com port name cannot be empty.\n");
                    output_help();
                    return -1;
                }
                break;

            case 'Z':

                    // Store the control method
                    test_params->control_method = optarg;
    
                    // Ensure that the control method is valid (either "serial" or "network")
                    if (strcmp(test_params->control_method, "serial") != 0 && strcmp(test_params->control_method, "network") != 0) {
                        fprintf(stderr, "[ERROR] - Invalid control method specified. It must be either 'serial' or 'network'.\n");
                        output_help();
                        return -1;
                    }
                    break;

            case 'L':
            
                // Store the user provided local IP address
                controller_interfaces->local_ip = optarg;

                // Ensure that the local IP address is not empty
                if (controller_interfaces->local_ip == NULL || strlen(controller_interfaces->local_ip) == 0) {
                    fprintf(stderr, "[ERROR] - Local IP address cannot be empty.\n");
                    output_help();
                    return -1;
                }

                // Validate the local IP address format
                if (!validate_ip(controller_interfaces->local_ip)) {
                    fprintf(stderr, "[ERROR] - Invalid local IP address format: %s\n", controller_interfaces->local_ip);
                    output_help();
                    return -1;
                }
                break;

            case 'Q':

                // Store the user provided remote IP address
                controller_interfaces->remote_ip = optarg;

                // Ensure that the remote IP address is not empty
                if (controller_interfaces->remote_ip == NULL || strlen(controller_interfaces->remote_ip) == 0) {
                    fprintf(stderr, "[ERROR] - Remote IP address cannot be empty.\n");
                    output_help();
                    return -1;
                }

                // Validate the remote IP address format
                if (!validate_ip(controller_interfaces->remote_ip)) {
                    fprintf(stderr, "[ERROR] - Invalid remote IP address format: %s\n", controller_interfaces->remote_ip);
                    output_help();
                    return -1;
                }

                break;

            case 'N':

                // Store the custom local port number
                controller_interfaces->local_port = atoi(optarg);

                // Ensure that the local port number is a valid integer and is within the valid port range
                if (controller_interfaces->local_port < 1 || controller_interfaces->local_port > 65535) {
                    fprintf(stderr, "[ERROR] - Invalid local port number. It must be an integer between 1 and 65535.\n");
                    output_help();
                    return -1;
                }

                // Check if the custom local port number is available for use on the system
                if (check_port_availability(controller_interfaces->local_port, "UDP") != 0) {
                    fprintf(stderr, "[ERROR] - The provided custom local port %d is not available on the system for use in the network controller.\n", controller_interfaces->local_port);
                    output_help();
                    return -1;
                }

                // Set the custom local port used flag
                custom_local_port = 1;
                break;

            case 'J':

                // Store the custom remote port number
                controller_interfaces->remote_port = atoi(optarg);

                // Ensure that the remote port number is a valid integer and is within the valid port range
                if (controller_interfaces->remote_port < 1 || controller_interfaces->remote_port > 65535) {
                    fprintf(stderr, "[ERROR] - Invalid remote port number. It must be an integer between 1 and 65535.\n");
                    output_help();
                    return -1;
                }

                // Set the custom remote port used flag
                custom_remote_port = 1;
                break;

            case 'h':

                // Output the help message and return success
                output_help();
                return 0;

            default:
                fprintf(stderr, "[ERROR] - Unknown command line argument: %s\n", argv[optind - 1]);
                output_help();
                return -1;

        }
        
    }

    // Ensure that if testing params have been set, that the control type is set to start test
    if ((test_params->test_type || test_params->test_algs || test_params->run_num || test_params->polling_rate) && test_params->control_type != 1) {
        fprintf(stderr, "[ERROR] - Testing parameters provided but control type is not set to start test.\n");
        output_help();
        return -1;
    }

    // Ensure that if control type is set to start test, that the required testing parameters have been provided and are valid
    if (test_params->control_type == 1) {
        if (!test_params->test_type || !test_params->test_algs || test_params->run_num <= 0 || test_params->polling_rate < 0.0f) {
            fprintf(stderr, "[ERROR] - Control type is set to start test but testing parameters are incomplete.\n");
            output_help();
            return -1;
        }
    }
    
    // Ensure that if control method is serial, that a com port name has been provided
    if (test_params->control_method && strcmp(test_params->control_method, "serial") == 0 && (controller_interfaces->com_port_name == NULL || strlen(controller_interfaces->com_port_name) == 0)) {
        fprintf(stderr, "[ERROR] - Control method is set to serial but no COM port name has been provided.\n");
        output_help();
        return -1;
    }

    // Ensure that if control method is network, that local and remote IP addresses have been provided
    if (test_params->control_method && strcmp(test_params->control_method, "network") == 0) {
        if (controller_interfaces->local_ip == NULL || strlen(controller_interfaces->local_ip) == 0 || controller_interfaces->remote_ip == NULL || strlen(controller_interfaces->remote_ip) == 0) {
            fprintf(stderr, "[ERROR] - Control method is set to network but local and/or remote IP address has not been provided.\n");
            output_help();
            return -1;
        }
    }

    // Ensure that a control method has been provided for control sender initialisation
    if (test_params->control_method == NULL || strlen(test_params->control_method) == 0) {
        fprintf(stderr, "[ERROR] - No control method specified in command line arguments\n");
        output_help();
        return -1;
    }

    // Check if the local port needs to be set to the default value and if it is available for use on the system
    if (custom_local_port == 0) {

        // Assign the default local port number
        controller_interfaces->local_port = 26001;

        // Check if the default local port number is available for use on the system before proceeding with the network controller configuration
        if (check_port_availability(controller_interfaces->local_port, "UDP") != 0) {
            fprintf(stderr, "[ERROR] - The default local port %d is not available on the system for use in the network controller.\n", controller_interfaces->local_port);
            return -1;
        }

    }

    // Check if the remote port needs to be set to the default value
    if (custom_remote_port == 0) {
        controller_interfaces->remote_port = 26000;
    }

    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------ 
int setup_env(TestController *test_controller, ControllerInterfaces *controller_interfaces) {
    /*  Function to handle the setup of the control_sender environment. This includes the configuration of the passed
        test controller instance using the specified controller interfaces. */

    // Ensure the control method is available before comparing it
    if (test_controller->control_type == NULL) {
        fprintf(stderr, "[ERROR] - Missing control method in test controller configuration\n");
        return -1;
    }

    // Configure the controller based on the specified control method
    if (strcmp(test_controller->control_type, "serial") == 0) {

        // Configure the serial controller settings
        test_controller->serial_controller = (SerialController) {
            .control_port_name = controller_interfaces->com_port_name,
            .control_port = NULL,
            .baudrate = 115200,
            .data_bits = 8,
            .parity = SP_PARITY_NONE,
            .stop_bits = 2,
            .flow_control = SP_FLOWCONTROL_NONE,
        };

        // Initialise the serial controller
        if (controller_init(test_controller) != 0) {
            fprintf(stderr, "[ERROR] - Failed to initialise the serial controller.\n");
            return -1;
        }

    }
    else if (strcmp(test_controller->control_type, "network") == 0) {

        // Configure the network controller settings
        test_controller->network_controller = (NetworkController) {
            .tcp_socket = -1,
            .udp_socket = -1,
            .local_port = controller_interfaces->local_port,
            .remote_port = controller_interfaces->remote_port,
            .net_protocol = "UDP",
            .local_address = controller_interfaces->local_ip,
            .remote_address = controller_interfaces->remote_ip,
        };

        // Initialise the network controller
        if (controller_init(test_controller) != 0) {
            fprintf(stderr, "[ERROR] - Failed to initialise the network controller.\n");
            return -1;
        }
    
    }
    else {
        fprintf(stderr, "[ERROR] - Invalid control method specified in test parameters.\n");
        return -1;
    }

    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------ 
int main(int argc, char *argv[]) {
    /*  Main function for the control sender script. It will handle the initialisation of the control sender environment, 
        parse the command line arguments, and perform the control action based on the specified parameters. */

    // Declare an instance of the test params struct
    TestParams test_params;

    // Initialise the test params values
    test_params = (TestParams){
        .control_method = NULL,
        .control_type = 0,
        .test_type = NULL,
        .test_algs = NULL,
        .iterations = 0,
        .total_runs = 0,
        .run_num = 0,
        .polling_rate = 0.0f
    };

    // Declare an instance of the controller interfaces struct and initialise the default values
    ControllerInterfaces controller_interfaces = {
        .com_port_name = NULL,
        .local_ip = NULL,
        .remote_ip = NULL,
        .local_port = 0,
        .remote_port = 0
    };

    // Ensure that command line arguments have been provided before attempting to parse them
    if (argc > 1) {

        // Parse the command line arguments
        if (parse_args(&test_params, &controller_interfaces, argc, argv) != 0) {
            fprintf(stderr, "[ERROR] - Failed to parse command line arguments.\n");
            return -1;
        }

    }
    else {
        fprintf(stderr, "[ERROR] - No command line arguments provided.\n");
        output_help();
        return -1;
    }

    // Declare the controller instance
    TestController test_controller;
    test_controller.control_type = test_params.control_method;
   
    // Setup the environment and initialise the test controller
    if (setup_env(&test_controller, &controller_interfaces) != 0) {
        fprintf(stderr, "Failed to setup the environment.\n");
        return -1;
    }

    // Perform the control action based on the control type using the control handler utility function
    if (control_handler(&test_controller, &test_params) != 0) {
        fprintf(stderr, "[ERROR] - Failed to perform the control action.\n");
        controller_close(&test_controller);
        return -1;
    }

    return 0;

}