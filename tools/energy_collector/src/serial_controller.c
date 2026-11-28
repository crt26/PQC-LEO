/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO serial controller backend used for control
signalling over a configured serial port. It initialises and configures port
settings, receives newline-delimited control messages, sends outbound command
messages, and closes/releases serial resources during shutdown.
*/

#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <time.h>
#include <serial_controller.h>

//-------------------------------------------------------------------------------------------------------------------------------
int serial_controller_init(SerialController *serial_controller) {
    /*  Function for initialising the SerialController instance. It will open the specified serial port and configure it with the
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
int serial_controller_receiver(SerialController *serial_controller, char *message, size_t message_size, int timeout_ms) {
    /*  Function for receiving messages from the control port. It reads until a newline or carriage return is received,
        using the supplied timeout for the full message when one is set. */

    // Ensure that the serial controller has been initialised properly
    if (serial_controller == NULL || serial_controller->control_port == NULL) {
        fprintf(stderr, "[ERROR] - The SerialController instance has not been initialised properly\n");
        return -1;
    }

    // Record the start time for the reply deadline
    struct timespec start_time;
    if (timeout_ms > 0 && clock_gettime(CLOCK_MONOTONIC, &start_time) != 0) {
        fprintf(stderr, "[ERROR] - Failed to start the serial control reply timer.\n");
        return -1;
    }

    // Declare the bytes read buffer and the current position in the buffer, as well as a variable for the read result
    char buffer[256];
    size_t buffer_position = 0;
    int read_result;

    // Read loop that runs until a newline or carriage return character is encountered, indicating the end of the message
    while (1) {

        // Define the timeout for the next single-byte read (if it stays at 0, receiver will wait indefinetty)
        unsigned int read_timeout_ms = 0;

        // Use the time remaining for the whole reply if a deadline was set
        if (timeout_ms > 0) {

            // Read the clock to check how long the reply has been pending
            struct timespec current_time;
            if (clock_gettime(CLOCK_MONOTONIC, &current_time) != 0) {
                fprintf(stderr, "[ERROR] - Failed to check the serial control reply timer.\n");
                return -1;
            }

            // Calculate the remaining reply time in milliseconds
            int64_t elapsed_seconds = (int64_t)current_time.tv_sec - start_time.tv_sec;
            int64_t elapsed_nanoseconds = elapsed_seconds * 1000000000 + current_time.tv_nsec - start_time.tv_nsec;
            int64_t remaining_ms = timeout_ms - elapsed_nanoseconds / 1000000;

            // Stop before reading again if the reply deadline has passed
            if (remaining_ms <= 0) {
                fprintf(stderr, "[ERROR] - Timed out waiting for a serial control message.\n");
                return -1;
            }

            // Update the read_timeout with the current remaining time for when a reply is due
            read_timeout_ms = (unsigned int)remaining_ms;

        }

        // Read the next byte from the control port using the selected timeout
        char current_byte;
        read_result = sp_blocking_read(serial_controller->control_port, &current_byte, 1, read_timeout_ms);
        if (read_result < 0) {
            fprintf(stderr, "[ERROR] - Failed to read from the serial control port.\n");
            return -1;
        }

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
