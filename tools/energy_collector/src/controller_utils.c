/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements shared controller utility functions for the PQC-LEO 
energy testing functionality. It provides serial port discovery and selection, 
control message tokenisation, GETREADY payload extraction/validation, and a control
handler that sends and receives messages using the configured controller backend.
*/

#include "controller_utils.h"

//-------------------------------------------------------------------------------------------------------------------------------
char* list_serial_ports() {
    /*  Helper function for listing the available serial ports that can be used for communication. The function will prompt the user
        to select which port to use for communication. This will then return a char array containing the selected port name. */

    // Query the system for the list of available serial ports
    struct sp_port **port_list;
    enum sp_return rc = sp_list_ports(&port_list);

    // Ensure the port query completed successfully
    if (rc != SP_OK) {
        fprintf(stderr, "[ERROR] - Failed to list serial ports (code: %d).\n", rc);
        return NULL;
    }

    // Ensure that ports were found
    if (port_list == NULL || port_list[0] == NULL) {
        printf("[WARNING] - No serial ports found.\n");
        if (port_list != NULL) {
            sp_free_port_list(port_list);
        }
        return NULL;
    }

    // Print the available serial ports and count the total number of ports
    int port_count = 0;
    printf("Available serial ports:\n");
    for (int i = 0; port_list[i] != NULL; i++) {

        // Get the port name and description
        const char *port_name = sp_get_port_name(port_list[i]);
        const char *port_desc = sp_get_port_description(port_list[i]);

        // Print the port information
        printf("%d: %s - %s\n", i + 1, port_name, port_desc);

        // Add port to the port count var
        port_count++;

    }

    // Declare the input and selection buffers
    char input[16];
    int selection;

    // Prompt the user for a port selection until a valid input is received
    while (1) {

        // Ask the user for port selection and store the input
        printf("Port selection: ");
        if (fgets(input, sizeof(input), stdin) == NULL) {
            fprintf(stderr, "[ERROR] - Failed to read port selection input.\n");
            sp_free_port_list(port_list);
            return NULL;
        }
        selection = atoi(input);

        // Ensure that the selection choice is valid
        if (selection > 0 && selection <= port_count) {

            // Store the selected port name
            const char *chosen_port = sp_get_port_name(port_list[selection - 1]);

            // Allocate memory for the selected port name
            char *selected_port_name = malloc(strlen(chosen_port) + 1);
            if (!selected_port_name) {
                fprintf(stderr, "Memory allocation failed.\n");
                exit(EXIT_FAILURE);
            }

            // Copy the selected port name into the allocated memory
            strcpy(selected_port_name, chosen_port);
            
            // Exit the loop
            sp_free_port_list(port_list);
            return selected_port_name;

        } 
        else {
            printf("Invalid selection. Please enter a number between 1 and %d.\n", port_count);

        }

    }

}

//------------------------------------------------------------------------------------------------------------------------------ 
void get_ip_address(char *ip_address, size_t ip_address_len) {
    /*  Helper function for prompting the user for an IP address and validating it. Once the input is validated, it is stored
        in the provided buffer. */

    // Prompt the user for the IP address until a valid value is provided
    while (1) {

        // Prompt the user for the IP address and store it
        char input[256];
        printf("Enter the IP address to use: ");
        fgets(input, sizeof(input), stdin);
        input[strcspn(input, "\n")] = '\0';

        // Validate the IP address format
        int octets[4];
        if (sscanf(input,"%d.%d.%d.%d", &octets[0], &octets[1], &octets[2], &octets[3]) == 4) {

            // Loop through the octets and check if they are within the valid range
            int valid = 1;
            for (int i = 0; i < 4; i++) {
                if (octets[i] < 0 || octets[i] > 255) {
                    valid = 0;
                    break;
                }
            }

            // Copy the validated IP address to the output buffer and return
            if (valid) {
                strncpy(ip_address, input, ip_address_len - 1);
                ip_address[ip_address_len - 1] = '\0';
                return;
            }

        }

        // Output that the IP is invalid and re-prompt
        printf("[WARNING] - Invalid IP address. Please enter a valid IPv4 address (e.g. 192.168.1.1).\n");

    }

}

//------------------------------------------------------------------------------------------------------------------------------ 
int check_port_availability(int port_number, const char *protocol_name) {
    /*  Helper function for checking whether the requested control port is available on the system for use. A successful check 
        will return 0, otherwise -1 with an appropriate error message being outputted. */

    // Determine which socket type to use for the port availability check based on the specified protocol
    int socket_type;
    if (strcmp(protocol_name, "TCP") == 0) {
        socket_type = SOCK_STREAM;
    }
    else if (strcmp(protocol_name, "UDP") == 0) {
        socket_type = SOCK_DGRAM;
    }
    else {
        fprintf(stderr, "[ERROR] - Invalid protocol type specified for port availability check. Must be 'TCP' or 'UDP'.\n");
        return -1;
    }

    // Open the test socket so the port can be tested by attempting to bind it
    int socket_fd = socket(AF_INET, socket_type, 0);
    if (socket_fd < 0) {
        fprintf(stderr, "[ERROR] - Failed to open test socket for port availability check: %s\n", strerror(errno));
        return -1;
    }

    // Prepare the test socket address for the requested port
    struct sockaddr_in socket_address;
    memset(&socket_address, 0, sizeof(socket_address));
    socket_address.sin_family = AF_INET;
    socket_address.sin_addr.s_addr = htonl(INADDR_ANY);
    socket_address.sin_port = htons((uint16_t)port_number);

    // Attempt to bind the socket to the requested port to see if it is available for use
    if (bind(socket_fd, (struct sockaddr *)&socket_address, sizeof(socket_address)) < 0) {

        // Store the error code and close the socket
        int error_code = errno;
        close(socket_fd);

        // Determine the reason for the bind failure and output the appropriate message to the terminal
        if (error_code == EADDRINUSE) {
            printf("[WARNING] - Port %d is already in use. Please choose a different port.\n", port_number);
            return -1;
        }
        else if (error_code == EACCES) {
            printf("[WARNING] - Port %d is privileged and cannot be used. Please choose a different port above 1024.\n", port_number);
            return -1;
        }
        else {
            fprintf(stderr, "[ERROR] - Failed to bind test socket for port availability check on port %d: %s\n", port_number, strerror(error_code));
            return -1;
        }

    }

    // Port is available, close the socket and return success
    close(socket_fd);
    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------ 
void get_port_number(int *port_number) {
    /*  Helper function for prompting the user to enter a network port number and validating it. */

    // Loop to prompt the user for a port number until a valid value is provided and the port is available
    int captured_port_num;

    // Prompt the user until a valid port number is provided
    while(1) {

        // Output the prompt, grab the input, and sanitise it
        printf("Enter the desired control port number to use: ");
        char input[16];
        fgets(input, sizeof(input), stdin);
        input[strcspn(input, "\n")] = '\0';

        // Convert the input to an integer and ensure it is in a valid range
        captured_port_num = atoi(input);
        if (captured_port_num < 1 || captured_port_num > 65535) {
            printf("[WARNING] - Invalid port number. Please enter a valid port number between 1 and 65535.\n");
            continue;
        }
        else {
            *port_number = captured_port_num;
            break;
        }

    }

}

//-------------------------------------------------------------------------------------------------------------------------------
int message_parser(char *message, char *command, char **message_elements, size_t message_elements_size) {
    /*  Function for parsing a provided message from the control port. It will extract any parameters from the message and store 
        them in the provided message_elements array. Primarily used for extracting the testing parameters from the GETREADY 
        message, it may be used for other message types given it follows the correct formatting. */

    // Ensure that the message is not empty
    if (message == NULL || message[0] == '\0') {
        fprintf(stderr, "[ERROR] - The passed message is empty\n");
        return -1;
    }

    // Calculate the number of elements that can be stored
    size_t max_elements = message_elements_size / sizeof(message_elements[0]);

    // Declare the token buffer and token index
    char *token;
    size_t token_index = 0;

    // Get the first element of the message and ensure it matches the expected command
    token = strtok(message, ":");
    if (token == NULL || strcmp(token, command) != 0) {
        fprintf(stderr, "[ERROR] - Invalid message format, expected '%c' as command but got '%s'.\n", *command, token);
        return -1;
    }

    // Loop through the rest of the message and extract the elements
    while ((token = strtok(NULL, ":")) != NULL) {

        // Ensure that the max number of elements has not been exceeded
        if (token_index >= max_elements) {
            fprintf(stderr, "[ERROR] - Too many message elements, max allowed is %zu\n", max_elements);
            return -1;
        }

        // Allocate the memory for the message element
        message_elements[token_index] = malloc(strlen(token) + 1);

        // Ensure that the memory allocation was successful
        if (message_elements[token_index] == NULL) {

            // Output a memory allocation error and free any previously allocated elements before returning
            fprintf(stderr, "[ERROR] - Memory allocation failed for message element %zu\n", token_index);

            for (size_t i = 0; i < token_index; i++) {
                free(message_elements[i]);
            }
            return -1;

        }

        // Copy the token into the current message element
        strcpy(message_elements[token_index], token);
        token_index++;

    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int get_ready_formatter(TestParams *test_params, char *get_ready_message, size_t message_size) {
    /*  Helper function for formatting the GETREADY message to be sent to the collector machine. It will format the message with
        the test parameters and return it in the provided buffer. */

    // Extract the test parameters from the TestParams struct and format the GETREADY message
    int ret = snprintf(
        get_ready_message, message_size, "GETREADY:%s:%s:%d:%f\n",
        test_params->test_type, 
        test_params->test_algs, 
        test_params->run_num, 
        test_params->polling_rate
    );

    // Determine if the message was formatted successfully
    if (ret < 0 || (size_t)ret >= message_size) {
        return -1;
    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int control_handler(TestController *test_controller, TestParams *test_params) {
    /*  Function for handling the control actions based on the control type specified in the TestParams struct. It will send the
        appropriate command to the collector machine based on the control type and parameters. */

    // Determine which control action to perform based on the set control type
    switch (test_params->control_type) {

        case 1:

            // Declare the GETREADY message and its size
            char get_ready_message[512];
            size_t message_size = sizeof(get_ready_message);

            // Prepare the GETREADY message with the test parameters
            if (get_ready_formatter(test_params, get_ready_message, message_size) != 0) {
                fprintf(stderr, "[ERROR] - Failed to format the GETREADY message.\n");
                return -1;
            }

            // Send the GETREADY message to the collector machine
            if (controller_send(test_controller, get_ready_message) != 0) {
                fprintf(stderr, "[ERROR] - Failed to send the GETREADY message.\n");
                return -1;  
            }

            // Wait for the ready message to be received from the collector machine
            char msg_buffer[256];
            if (controller_receive(test_controller, msg_buffer, sizeof(msg_buffer)) != 0) {
                fprintf(stderr, "[ERROR] - Failure in the controller receiver.\n");
                return -1;
            }

            // Check if the received message is "READY"
            if(strcmp(msg_buffer, "READY") == 0) {

                // Send the start command and exit immediately to begin the test as quickly as possible
                if (controller_send(test_controller, "START\n") != 0) {
                    fprintf(stderr, "[ERROR] - Failed to send the start command.\n");
                    return -1;
                }
                return 0;

            }
            else {
                fprintf(stderr, "[ERROR] - Unexpected message received: %s\n", msg_buffer);
                return -1;

            }

            break;

        case 2:

            // Send the STOP command to the collector machine
            if (controller_send(test_controller, "STOP\n") != 0) {
                fprintf(stderr, "[ERROR] - Failed to send the stop command.\n");
                return -1;
            }

            break;

        case 3:

            // Send the END command to the collector machine
            if (controller_send(test_controller, "END\n") != 0) {
                fprintf(stderr, "[ERROR] - Failed to send the end command.\n");
                return -1;
            }

            break;

        default:

            // Output an error message for an invalid control type and return failure
            fprintf(stderr, "[ERROR] - Invalid control type specified.\n");
            return -1;
            
    }

    return 0;

}
