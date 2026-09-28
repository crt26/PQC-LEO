/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO serial controller backend used for control
signalling over a configured serial port. It initialises and configures port
settings, receives newline-delimited control messages, sends outbound command
messages, and closes/releases serial resources during shutdown.
*/

#include <serial_controller.h>

//-------------------------------------------------------------------------------------------------------------------------------
int serial_controller_init(SerialController *serial_controller) {
    /*  Function for initialising the SerialController instance. It will open the specified COM port and configure it with the 
        specified parameters. */

    // Ensure that the serial controller struct is valid
    if (sp_get_port_by_name(serial_controller->control_port_name, &serial_controller->control_port) != SP_OK) {
        fprintf(stderr, "[ERROR] - Unable to find the control port - %s\n", serial_controller->control_port_name);
        return -1;
    }

    // Open the control port for read/write access
    if (sp_open(serial_controller->control_port, SP_MODE_READ_WRITE) != SP_OK) {
        fprintf(stderr, "[ERROR] - Unable to open the control port - %s\n", serial_controller->control_port_name);
        return -1;
    }

    // Configure the control port using the settings specified in the SerialController struct
    sp_set_baudrate(serial_controller->control_port, serial_controller->baudrate);
    sp_set_bits(serial_controller->control_port, serial_controller->data_bits);
    sp_set_parity(serial_controller->control_port, serial_controller->parity);
    sp_set_stopbits(serial_controller->control_port, serial_controller->stop_bits);
    sp_set_flowcontrol(serial_controller->control_port, serial_controller->flow_control);

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int serial_controller_receiver(SerialController *serial_controller, char *message, size_t message_size) {
    /*  Function for receiving messages from the control port. It will read bytes until it encounters a newline or carriage 
        return character, and then copy the received message into the provided buffer. */

    // Ensure that the serial controller has been initialised properly
    if (serial_controller == NULL || serial_controller->control_port == NULL) {
        fprintf(stderr, "[ERROR] - The SerialController instance has not been initialised properly\n");
        return -1;
    }

    // Declare the bytes read buffer and the current position in the buffer, as well as a variable for the read result
    char buffer[256];
    size_t buffer_position = 0;
    int read_result;

    // Read loop that runs until a newline or carriage return character is encountered, indicating the end of the message
    while (1) {

        // Clear the current byte and read in from the control port
        char current_byte;
        read_result = sp_blocking_read(serial_controller->control_port, &current_byte, 1, 100);

        // Ensure that the read was successful
        if (read_result > 0) {
            
            // Check if the current byte is a char that indicates the end of the message
            if (current_byte == '\n' || current_byte == '\r') {

                // Null terminate the buffer and copy it into the message
                buffer[buffer_position] = '\0';
                strncpy(message, buffer, message_size - 1);
                message[message_size - 1] = '\0';
                break;

            }

            // Process the received byte if there is room in the buffer
            if (buffer_position < sizeof(buffer) - 1) {
                buffer[buffer_position++] = current_byte;
            } else {
                fprintf(stderr, "[ERROR] - Buffer overflow while reading from control port\n");
                return -1;
            }

        }

    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int serial_controller_send(SerialController *serial_controller, char *message) {
    /*  Function for sending serial messages to the control port. It will write the provided message to the control port and 
        handle any errors. The message is sent exactly as provided (no terminator is appended). */

    // Ensure that the serial controller has been initialised properly
    if (serial_controller == NULL || serial_controller->control_port == NULL) {
        fprintf(stderr, "[ERROR] - The SerialController instance has not been initialised properly\n");
        return -1;
    }

    // Ensure that the message is not empty
    if (message[0] == '\0') {
        fprintf(stderr, "[ERROR] - The command message is empty\n");
        return -1;
    }

    // Write the message to the control port
    int status = sp_blocking_write(serial_controller->control_port, message, strlen(message), 1000);

    // Check if the write was successful
    if (status < 0) {
        fprintf(stderr, "[ERROR] - Failed to write message to control port: %s\n", sp_last_error_message());
        return -1;
    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int serial_controller_close(SerialController *serial_controller) {
    /* Function for closing the serial controller and releasing resources. */

    // Ensure that the serial controller has been initialised properly
    if (serial_controller == NULL || serial_controller->control_port == NULL) {
        fprintf(stderr, "[ERROR] - The SerialController instance has not been initialised properly\n");
        return -1;
    }

    // Close the control port
    sp_close(serial_controller->control_port);
    sp_free_port(serial_controller->control_port);

    return 0;

}