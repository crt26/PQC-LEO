/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO controller interface abstraction. It provides
a unified API for initialising, sending, receiving, and closing control channels
across supported controller types (serial or network). It validates controller
configuration and performs each control operation using the appropriate backend-specific
handler.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "controller_api.h"

//-------------------------------------------------------------------------------------------------------------------------------
int controller_init(TestController *controller) {
    /*  Function for initialising the controller instance based on the specified control type. It will call the relevant 
        initialisation function for the specified control type and return any errors. */

    // Ensure that the controller struct is valid
    if (controller == NULL) {
        fprintf(stderr, "[ERROR] - The TestController instance is NULL\n");
        return -1;
    }

    // Determine which control type to initialise based on the control_type field in the controller struct
    if (strcmp(controller->control_type, "serial") == 0) {
        serial_controller_init(&controller->serial_controller);
    } 
    else if (strcmp(controller->control_type, "network") == 0) {
        network_controller_init(&controller->network_controller);
    } 
    else {
        fprintf(stderr, "[ERROR] - Invalid control type specified: %s\n", controller->control_type);
        return -1;
    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int controller_send(TestController *controller, char *message) {
    /*  Function for sending control signal messages using the controller instance based on the specified control type. 
        It will call the relevant sending function for the specified control type and return any errors. */

    // Determine which control type to use when sending the message
    if (strcmp(controller->control_type, "serial") == 0) {
        serial_controller_send(&controller->serial_controller, message);
    }
    else if (strcmp(controller->control_type, "network") == 0) {
        network_controller_send(&controller->network_controller, message);
    }
    else {
        fprintf(stderr, "[ERROR] - Invalid control type specified: %s\n", controller->control_type);
        return -1;
    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int controller_receive(TestController *controller, char *message, size_t message_size) {
    /*  Function for receiving control signal messages using the controller instance based on the specified control type. 
        It will call the relevant receiving function for the specified control type and return any errors. */

    // Determine which control type to use when receiving the message
    if (strcmp(controller->control_type, "serial") == 0) {
        serial_controller_receiver(&controller->serial_controller, message, message_size);
    }
    else if (strcmp(controller->control_type, "network") == 0) {
        network_controller_receiver(&controller->network_controller, message, message_size);

    }
    else {
        fprintf(stderr, "[ERROR] - Invalid control type specified: %s\n", controller->control_type);
        return -1;
    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int controller_close(TestController *controller) {
    /*  Function for closing the controller instance based on the specified control type. It will call the relevant closing 
        function for the specified control type and return any errors. */

    // Determine which control type to use when closing the controller
    if (strcmp(controller->control_type, "serial") == 0) {
        serial_controller_close(&controller->serial_controller);
    }
    else if (strcmp(controller->control_type, "network") == 0) {
        network_controller_close(&controller->network_controller);
    }
    else {
        fprintf(stderr, "[ERROR] - Invalid control type specified: %s\n", controller->control_type);
        return -1;
    }

    return 0;

}