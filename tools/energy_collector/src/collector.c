/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO energy metric collector. It configures control signalling
(serial or network), initialises the connected meter device, manages results storage, and runs
threaded listeners for test control commands and energy metric polling. During execution, it
handles GETREADY/STOP/END commands, writes sampled power data to per-test output files,
and coordinates clean shutdown of controller and collection resources.

*/

#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>
#include <sys/stat.h>
#include <pthread.h>
#include <getopt.h>
#include <time.h>
#include "collector.h"

// Declare the global variables used throughout the collector script
static char results_dir[256];
int custom_net_ports = 0;

// Declare the shared thread variables used to pass one control command at a time
static pthread_mutex_t control_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t control_changed = PTHREAD_COND_INITIALIZER;
static ControlCommand pending_command;
static int command_pending;
static int command_exit_status;
static int control_failed;

//------------------------------------------------------------------------------------------------------------------------------ 
void output_help() {
    /*  Function for outputting the help message for the collector script. It will display the usage, options, and their 
        descriptions. */

    // Print the help message
    printf("Usage: collector [OPTIONS]\n");
    printf("Options:\n");
    printf("-d, --results-dir=<dir>                 Specify the directory to store results in (if not provided, will prompt for it during setup)\n");
    printf("-s, --skip-welcome-message              Skip the welcome message on startup (useful for automated calling of the script)\n");
    printf("-c, --use-custom-net-control-ports      Use custom network control ports for energy testing control signalling\n");
    printf("-h, --help                              Display this help message and exit\n");

}

//------------------------------------------------------------------------------------------------------------------------------ 
void parse_args(int argc, char *argv[], int *display_welcome, int *prompt_for_result_dir) {
    /*  Function for parsing the command line arguments passed to the collector program. The function will parse the arguments
        and set the appropriate flags and values. If an error is encountered, the function will display an error message and the
        help message before exiting. */
    
    // Define the getopt_long struct and options
    struct option long_options[] = {
        {"results-dir", required_argument, 0, 'd'},
        {"skip-welcome-message", no_argument, 0, 's'},
        {"use-custom-net-control-ports", no_argument, 0, 'c'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    // Declare the option and index variables
    int option;
    int option_index = 0;

    // Parse the command line arguments
    while((option = getopt_long(argc, argv, "d:hsc", long_options, &option_index)) != -1) {

        // Determine which option is being processed
        switch (option) {

            case 'd':
            
                // Store the provided results directory path in the global variable
                strncpy(results_dir, optarg, sizeof(results_dir) - 1);
                results_dir[sizeof(results_dir) - 1] = '\0';

                // Ensure that the provided directory does not already exist to prevent overwriting previous results
                if (access(results_dir, F_OK) != -1) {
                    fprintf(stderr, "[ERROR] - Results directory already exists: %s\n", results_dir);
                    output_help();
                    exit(1);
                }

                // Set the prompt for result dir flag to false
                *prompt_for_result_dir = 0;

                break;

            case 'h':

                // Output the help message and return success
                output_help();
                exit(0);

            case 's':

                // Set the skip welcome message flag
                *display_welcome = 0;
                break;

            case 'c':

                // Set the use custom network control ports flag
                custom_net_ports = 1;
                break;

            default:

                // Output the error message to the terminal and return failure
                fprintf(stderr, "[ERROR] - Unknown command line argument: %s\n", argv[optind - 1]);
                output_help();
                exit(1);

        }
        
    }

}

//------------------------------------------------------------------------------------------------------------------------------ 
int configure_controller(TestController *test_controller) {
    /*  Function for configuring the control communication method for communicating with the energy collector based on user 
        input. The function prompts the user to select the control communication method (serial or network) and then collects 
        the relevant configuration information based on the selected method. */

    // Determine which control method is being used
    if (strcmp(test_controller->control_type, "serial") == 0) {

        // Configure the serial controller settings
        test_controller->serial_controller = (SerialController) {
            .control_port = NULL,
            .baudrate = 115200,
            .data_bits = 8,
            .parity = SP_PARITY_NONE,
            .stop_bits = 2,
            .flow_control = SP_FLOWCONTROL_NONE,
        };

        // Get the serial port to be used for the serial controller
        printf("Please select the serial port for serial control signals:\n");
        char *control_port_name =  list_serial_ports();

        // Check if a control port name was returned
        if (control_port_name == NULL) {
            fprintf(stderr, "[ERROR] - No serial ports are available, please verify connectivity\n");
            free(control_port_name);
            exit(1);
        }

        // Store the control port name in the serial controller instance
        test_controller->serial_controller.control_port_name = control_port_name;

        // Initialise the serial controller
        if (controller_init(test_controller) != 0) {
            fprintf(stderr, "[ERROR] - Failed to initialise the serial controller.\n");
            free(control_port_name);
            return -1;
        }

        // Free the port name
        free(control_port_name);
        printf("\n");

        return 0;

    }
    else if (strcmp(test_controller->control_type, "network") == 0) {

        /*Insert here future prompt to ask whether to use UDP or TCP when TCP is supported*/

        // Define the default local and remote port numbers to be used for the network controller
        int local_port = 26000;
        int remote_port = 26001;

        // Define the local and remote IP variables used by the network controller configuration
        char local_ip[16];
        char remote_ip[16];

        // Get the local and remote IP addresses to be used for the network controller
        printf("Configure the local device listening IP:\n");
        get_ip_address(local_ip, sizeof(local_ip));
        printf("\n");

        printf("Configure the remote device listening IP:\n");
        get_ip_address(remote_ip, sizeof(remote_ip));
        printf("\n");

        // Determine if the user needs to be prompted for the custom local and remote port numbers
        if (custom_net_ports == 1) {

            // Prompt the user for the local port number until a available port is provided
            printf("Configure the Local Device Network Port:\n");
            while (1) {

                // Prompt the user for the local port number and store it in the local_port variable
                get_port_number(&local_port);

                // Check if the provided local port number is available for use
                if (check_port_availability(local_port, "UDP") == 0) {
                    break;
                }
                else {
                    fprintf(stderr, "[ERROR] - The provided local port %d is not available on the system for use in the network controller.\n", local_port);
                }

            }
            printf("\n");

            // Prompt the user for the remote port number until a valid port is provided
            printf("Configure the Remote Device Network Port:\n");
            get_port_number(&remote_port);
            printf("\n");

        }

        // If using the default local port number, check if it is available before proceeding with the network controller configuration
        if (custom_net_ports == 0) {
            if (check_port_availability(local_port, "UDP") != 0) {
                fprintf(stderr, "[ERROR] - The default local port %d is not available on the system for use in the network controller.\n", local_port);
                return -1;
            }
        }

        // Configure the network controller
        test_controller->network_controller = (NetworkController) {
            .tcp_socket = -1,
            .udp_socket = -1,
            .local_port = local_port,
            .remote_port = remote_port,
            .net_protocol = "UDP",
            .local_address = local_ip,
            .remote_address = remote_ip,
        };

        // Initialise the network controller
        if (controller_init(test_controller) != 0) {
            fprintf(stderr, "[ERROR] - Failed to initialise the network controller.\n");
            return -1;
        }

        return 0;

    }

    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------ 
static MeterType prompt_meter_type(void) {
    /*  Function for prompting the user to select the energy meter type to use for testing. It will output the supported
        meter options stored in the supported_meter_types array, validate the selected option number, and return the
        mapped MeterType value. */

    // Output the current task to the terminal
    printf("Energy Meter Device Selection:\n\n");

    // Calculate the number of available meter type options based on the size of the supported_meter_types array
    const size_t total_meter_types = sizeof(supported_meter_types) / sizeof(supported_meter_types[0]);

    // Ensure that at least one meter type is available for selection
    if (total_meter_types == 0) {
        fprintf(stderr, "[ERROR] - No supported meter types are configured.\n");
        return METER_TYPE_UNKNOWN;
    }

    // Prompt the user for their energy meter selection until a valid selection is made
    while (1) {

        // Output the currently supported energy meter options from the mapping table 
        printf("Supported energy meter device types:\n");
        for (size_t option_index = 0; option_index < total_meter_types; option_index++) {
            printf("%d) %s\n", supported_meter_types[option_index].option_number, supported_meter_types[option_index].name);
        }
        printf("Enter meter type selection: ");

        // Read in the user input and convert to a integer
        char input[16];
        fgets(input, sizeof(input), stdin);
        input[strcspn(input, "\n")] = '\0';
        int selection = atoi(input);

        // Ensure that the selection integer is valid and within the range of available meter type options
        if (selection < 1 || selection > (int)total_meter_types) {
            fprintf(stderr, "\n[WARNING] - Invalid meter type selection input: %s\n\n", input);
            continue;
        }

        // Return the MeterType corresponding to the selected option number from the supported_meter_types array
        for (size_t option_index = 0; option_index < total_meter_types; option_index++) {
            if (selection == supported_meter_types[option_index].option_number) {
                return supported_meter_types[option_index].type;
            }
        }

    }

}

//------------------------------------------------------------------------------------------------------------------------------ 
int setup_env(TestController *test_controller, MeterDevice *meter_device, int prompt_for_result_dir) {
    /*  Function to handle the setup of the collector environment. This includes the configuration of the passed test controller 
        and the energy meter device instances, alongside the configuration of the result storage. */

    // Output the current task to the terminal
    printf("-----------------------------\n");
    printf("Test Controller Configuration\n");
    printf("-----------------------------\n\n");

    // Prompt the user for the control method to use until a valid selection is made
    while (1) {

        // Prompt the user for the control method to use and store the input
        printf("Available controller communication methods:\n1: Serial (UART)\n2: Network\n");
        printf("Enter method selection (1/2): ");
        char input[16];
        fgets(input, sizeof(input), stdin);
        input[strcspn(input, "\n")] = '\0';
        printf("\n");

        // Determine the control type based on the user input and set it in the TestController struct
        if (strcmp(input, "1") == 0) {
            test_controller->control_type = "serial";
            break;
        }
        else if (strcmp(input, "2") == 0) {
            test_controller->control_type = "network";
            break;
        }
        else {
            fprintf(stderr, "\n[WARNING] - Invalid selection input: %s\n\n", input);
        }

    }

    // Configure the controller based on the selected control type
    if (configure_controller(test_controller) != 0) {
        fprintf(stderr, "[ERROR] - Failed to configure the test controller.\n");
        return -1;
    }

    // Output the current task to the terminal
    printf("---------------------------------\n");
    printf("Energy Meter Device Configuration\n");
    printf("---------------------------------\n");

    // Prompt the user for the energy meter type and validate the selected backend
    MeterType selected_meter_type = prompt_meter_type();
    if (selected_meter_type == METER_TYPE_UNKNOWN) {
        fprintf(stderr, "[ERROR] - No valid energy meter type was selected.\n");
        return -1;
    }
    printf("\n");

    // Get the serial port to be used for the energy meter device
    printf("Please select the serial port for communicating with the energy meter device:\n\n");
    char *control_port_name = list_serial_ports();

    // Check if a control port name was returned
    if (control_port_name == NULL) {
        fprintf(stderr, "[ERROR] - No serial ports are available, please verify connectivity\n");
        free(control_port_name);
        exit(1);
    }

    // Initialise the energy meter device with the selected serial port
    if (meter_init(meter_device, selected_meter_type, control_port_name) != 0) {
        fprintf(stderr, "[ERROR] - Failed to initialise the energy meter device.\n");
        free(control_port_name);
        return -1;
    }

    // Free the meter serial port name
    free(control_port_name);

    // Check if the user needs to be prompted for the name of the target results directory
    if (prompt_for_result_dir == 1) {

        // Output the current task to the terminal
        printf("\n-----------------------------\n");
        printf("Results Storage Configuration\n");
        printf("-----------------------------\n\n");

        // Prompt the user for a results directory name until a valid value is provided and the directory is created successfully
        while (1) {

            // Prompt the user for the name of the results directory to store the energy metrics in
            char input[256];
            printf("Enter the name of the directory to store results in: ");

            // Ensure that the input is read successfully and handle the case where it is not
            if (fgets(input, sizeof(input), stdin) == NULL) {
                fprintf(stderr, "[ERROR] - Failed to read results directory name.\n");
                return -1;
            }
            input[strcspn(input, "\n")] = '\0';

            if (input[0] == '\0') {
                fprintf(stderr, "[WARNING] - Results directory name cannot be empty.\n");
                continue;
            }

            // Store the provided results directory name in the global variable
            strncpy(results_dir, input, sizeof(results_dir) - 1);
            results_dir[sizeof(results_dir) - 1] = '\0';

            // Check if the provided results directory already exists before proceeding
            if (access(results_dir, F_OK) == 0) {
                printf("[NOTICE] - Results directory already exists. Please choose a different directory name.\n");
            }
            else {
                break;
            }
        
        }
    
    }

    // Attempt to create the directory where results will be stored
    if (mkdir(results_dir, 0755) != 0) {
        fprintf(stderr, "[ERROR] - Failed to create results directory: %s\n", results_dir);
        return -1;
    }
    
    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------
static void free_message_elements(char **message_elements, size_t element_count) {
    /* Helper function to free memory allocated for GETREADY message array elements. */

    // Loop through the message elements array and free each allocated element
    for (size_t index = 0; index < element_count; index++) {
        free(message_elements[index]);
        message_elements[index] = NULL;
    }

}

//-------------------------------------------------------------------------------------------------------------------------------
int get_ready_parser(char *message, ControlCommand *get_ready_command) {
    /*  Function for parsing the GETREADY message and passing the results filepath and polling interval to the collection
        thread. The collection thread opens the file and records the baseline reading before returning the command result. */

    // Reject empty fields before the parser skips consecutive delimiters
    size_t message_length = message == NULL ? 0 : strlen(message);
    if (message_length > 0 && (strstr(message, "::") != NULL || message[message_length - 1] == ':')) {
        fprintf(stderr, "[ERROR] - GETREADY message contains an empty field.\n");
        return -1;
    }

    // Declare the message elements array and its size
    char *message_elements[4];
    size_t array_size = sizeof(message_elements);
    size_t element_count = sizeof(message_elements) / sizeof(message_elements[0]);

    // Initialise the message elements array with NULL pointers
    for (size_t i = 0; i < element_count; i++) {
        message_elements[i] = NULL;
    }

    // Parse the received message to extract the test parameters
    if (message_parser(message, "GETREADY", message_elements, array_size) != 0) {
        fprintf(stderr, "[ERROR] - Failed to parse the GETREADY message.\n");
        return -1;
    }

    // Ensure that every required GETREADY parameter was received
    for (size_t i = 0; i < element_count; i++) {
        if (message_elements[i] == NULL) {
            fprintf(stderr, "[ERROR] - GETREADY message is missing required parameters.\n");
            free_message_elements(message_elements, element_count);
            return -1;
        }
    }

    // Set the filename based on the received GETREADY message parameters then store its length
    char filename[512];
    int filename_length = snprintf(filename, sizeof(filename), "%s_%s_%s.txt", message_elements[0], message_elements[1], message_elements[2]);

    // Ensure that the filename length is valid and does not exceed the buffer size
    if (filename_length < 0 || (size_t)filename_length >= sizeof(filename)) {
        fprintf(stderr, "[ERROR] - Energy result filename is too long.\n");
        free_message_elements(message_elements, element_count);
        return -1;
    }

    // Keep the result file inside the selected results directory
    if (strchr(filename, '/') != NULL) {
        fprintf(stderr, "[ERROR] - Energy result filename contains a path separator.\n");
        free_message_elements(message_elements, element_count);
        return -1;
    }

    // Set the filepath based on the results directory and filename then store its length
    int filepath_length = snprintf(get_ready_command->output_filepath, sizeof(get_ready_command->output_filepath), "%s/%s", results_dir, filename);

    // Ensure that the filepath length is valid and does not exceed the buffer size
    if (filepath_length < 0 || (size_t)filepath_length >= sizeof(get_ready_command->output_filepath)) {
        fprintf(stderr, "[ERROR] - Energy result filepath is too long.\n");
        free_message_elements(message_elements, element_count);
        return -1;
    }

    // Read in the polling rate and convert from milliseconds to microseconds
    char *polling_rate_end;
    double captured_polling_rate = strtod(message_elements[3], &polling_rate_end) * 1000.0;

    // Ensure that the polling rate is fully parsed and within the supported range
    if (*polling_rate_end != '\0' || !(captured_polling_rate >= 0.0 && captured_polling_rate <= UINT_MAX)) {
        fprintf(stderr, "[ERROR] - Invalid polling rate received in GETREADY message: %s\n", message_elements[3]);
        free_message_elements(message_elements, element_count);
        return -1;
    }

    // Convert polling rate variable type and store in command record
    get_ready_command->polling_rate = (useconds_t)captured_polling_rate;

    // Free the GETREADY message array elements
    free_message_elements(message_elements, element_count);
    
    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------
static int submit_control_command(const ControlCommand *control_command) {
    /*  Function for passing a control command to the collection thread and waiting for the result before the listener
        receives another command. */

    // Store the command and signal the collection thread
    pthread_mutex_lock(&control_lock);
    pending_command = *control_command;
    command_pending = 1;
    pthread_cond_signal(&control_changed);

    // Wait for the collection thread to store the result and clear the pending command flag
    while (command_pending) {
        pthread_cond_wait(&control_changed, &control_lock);
    }

    // Capture the command exit status and release the thread lock
    int command_result = command_exit_status;
    pthread_mutex_unlock(&control_lock);

    return command_result;

}

//------------------------------------------------------------------------------------------------------------------------------ 
void *control_listener_thread(void *arg) {
    /*  Function for handling the control listener thread. It receives commands from the control port and waits for the
        collection thread to complete GETREADY or STOP before sending READY or SAVED. */

    // Cast the argument to TestController type
    TestController *test_controller = (TestController *)arg;
    printf("[NOTICE] - Waiting for first connection...\n");

    // Loop to handle control signalling until testing is complete
    while (1) {

        // Wait for the next command from the testing machine
        char msg_buffer[512];
        if (controller_receive(test_controller, msg_buffer, sizeof(msg_buffer), 0) != 0) {
            fprintf(stderr, "[ERROR] - Failure in the controller receiver.\n");
            control_failed = 1;
            break;
        }

        // Define the command exit code and required reply variables
        int command_exit_code = -1;
        char *reply_message = NULL;

        // Determine which command to pass to the collection thread
        if (strncmp(msg_buffer, "GETREADY:", 9) == 0 || strcmp(msg_buffer, "GETREADY") == 0) {

            // Create a GETREADY command record and set the action
            ControlCommand get_ready_command;
            get_ready_command.action = CONTROL_GETREADY;

            // Define the reply message as READY
            reply_message = "READY\n";

            // Submit the GETREADY command only after all parameters have been parsed
            if (get_ready_parser(msg_buffer, &get_ready_command) == 0) {
                command_exit_code = submit_control_command(&get_ready_command);
            }

        }
        else if (strcmp(msg_buffer, "STOP") == 0) {

            // Create the STOP command record and set the action
            ControlCommand stop_command;
            stop_command.action = CONTROL_STOP;

            // Submit the STOP command to the collection thread to and capture the command exit code
            command_exit_code = submit_control_command(&stop_command);
            printf("[NOTICE] - Received STOP command, stopping energy metrics collection...\n\n");

            // Define the reply message as SAVED
            reply_message = "SAVED\n";

        }
        else if (strcmp(msg_buffer, "END") == 0) {

            // Output the received message to the terminal and exit collection loop
            printf("[NOTICE] - Received END command, ending energy metrics collection...\n\n");
            break;

        }
        else {

            // Output error to terminal for unknown command and set the control failed flag
            fprintf(stderr, "[ERROR] - Unknown command received: %s\n", msg_buffer);
            control_failed = 1; // NOTE - check why and what this is used for 
            break;

        }
        
        // Send an ERROR code and end the session if GETREADY or STOP fails
        if (command_exit_code != 0) {
            fprintf(stderr, "[ERROR] - Failed to process %s.\n", msg_buffer);
            control_failed = 1; // NOTE - check why and what this is used for
            break;
        }

        // Send the control reply based on the received message and check for error
        if (controller_send(test_controller, reply_message) != 0) {
            fprintf(stderr, "[ERROR] - Failed to send the boundary reply.\n");
            control_failed = 1;
            break;
        }

    }

    // Create the END command record
    ControlCommand end_command;
    end_command.action = CONTROL_END;

    // Submit the END command to the collection thread
    if (submit_control_command(&end_command) != 0) {
        control_failed = 1;
    }

    // Send an ERROR message to the tester machine if a contorl action failed
    if (control_failed == 1) {
        controller_send(test_controller, "ERROR\n");
    }

    return NULL;

}

//------------------------------------------------------------------------------------------------------------------------------
// NOTE - Consider renaming function
static int write_energy_reading(MeterDevice *meter_device, EnergyCollection *energy_collection, int first_reading) {
    /*  Function for polling the meter and writing the reading to the current metrics file. The first reading sets the
        starting time and energy values for the operation. */

    // Poll the meter and record the current time after a successful reading
    MeterReading meter_reading;
    struct timespec current_time;
    if (meter_poll(meter_device, &meter_reading) != 0 || clock_gettime(CLOCK_MONOTONIC, &current_time) != 0) {
        return -1;
    }

    // Store the initial values for the current operation
    if (first_reading) {
        energy_collection->start_mAh = meter_reading.mAh;
        energy_collection->start_mWh = meter_reading.mWh;
        energy_collection->start_time = current_time;
    }

    // Calculate elapsed time in milliseconds since the first reading (NOTE REVIEW)
    double elapsed_time_ms = (double)(current_time.tv_sec - energy_collection->start_time.tv_sec) * 1000.0
                           + (double)(current_time.tv_nsec - energy_collection->start_time.tv_nsec) / 1000000.0;

    // Calculate energy usage relative to the starting meter values
    unsigned int display_mWh = meter_reading.mWh - energy_collection->start_mWh;
    unsigned int display_mAh = meter_reading.mAh - energy_collection->start_mAh;
    float joules = (float)display_mWh * 3.6f;

    // Write out the metrics gathered from the poll to the file
    int write_exit_code = fprintf(
        energy_collection->metrics_file,
        "Voltage: %.2f V | Current: %.2f A | Power: %.2f W | mWh: %u | mAh: %u | Joules: %.2f | Elapsed Time: %f ms\n",
        meter_reading.voltage, meter_reading.current, meter_reading.power, display_mWh, display_mAh, joules, elapsed_time_ms
    );

    // Set the function return code based on how the write went
    int return_code = write_exit_code < 0 ? -1 : 0;

    return return_code;

}

//------------------------------------------------------------------------------------------------------------------------------
static int close_metrics_file(EnergyCollection *energy_collection, int discard) {
    /*  Function for closing the current metrics file and removing it if the measurement is incomplete or if a write or
        close operation failed. It returns 0 on success or -1 if a write, close, or removal failed. */

    // Check if the file is already closed before proceeding
    if (energy_collection->metrics_file == NULL) {
        return 0;
    }

    // Check if there were any previous write errors and store the result
    int write_failed = ferror(energy_collection->metrics_file);

    // Close the metrics file and reset the file pointer in the energy collection struct
    int close_file_exit_code = fclose(energy_collection->metrics_file);
    energy_collection->metrics_file = NULL;

    // Set the return code based on the write and close results
    int return_code = write_failed || close_file_exit_code != 0 ? -1 : 0;

    // Remove the metrics file if the measurement is incomplete or a file operation failed
    if ((discard || return_code != 0) && unlink(energy_collection->output_filepath) != 0) {
        fprintf(stderr, "[ERROR] - Failed to remove incomplete metrics file: %s\n", energy_collection->output_filepath);
        return -1;
    }

    return return_code;

}

//------------------------------------------------------------------------------------------------------------------------------
static int calculate_next_poll_time(useconds_t polling_rate, struct timespec *next_poll_time) {
    /*  Helper function for calculating the time of the next meter poll. It adds the polling interval in microseconds to
        the current time and stores the deadline in next_poll_time for pthread_cond_timedwait(). It returns 0 on success
        or -1 if the current time could not be read. */

    // Capture the current time so that it can be used to calculate what time the next poll should be
    if (clock_gettime(CLOCK_REALTIME, next_poll_time) != 0) {
        fprintf(stderr, "[ERROR] - Failed to get the clock when calculating time to wait till next poll\n");
        return -1;
    }

    // Add the interval time to the current time to calculate the time of next poll (after converting seconds/nanoseconds)
    next_poll_time->tv_sec += (time_t)(polling_rate / 1000000);
    next_poll_time->tv_nsec += (long)((polling_rate % 1000000) * 1000);

    // Carry any whole second from the nanoseconds field into the seconds field before returning
    next_poll_time->tv_sec += next_poll_time->tv_nsec / 1000000000;
    next_poll_time->tv_nsec %= 1000000000;

    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------
void *collect_energy_metrics_thread(void *arg) {
    /*  Function for handling the energy metrics collection thread. This thread opens, writes, and closes the current
        metrics file so a poll always finishes in the file for the operation that started it. */

    // Cast the argument to MeterDevice type and initialise the collection state
    MeterDevice *meter_device = (MeterDevice *)arg;
    EnergyCollection energy_collection = {0};
    int poll_meter = 0;

    // Loop to handle control commands and collect energy metrics until testing is complete
    pthread_mutex_lock(&control_lock);
    while (1) {

        // Wait for an incoming command when not polling
        while (!command_pending && !poll_meter) {
            pthread_cond_wait(&control_changed, &control_lock);
        }

        // Check if a command is pending and process it if there is
        if (command_pending) {

            // Create a copy of the command and release the variable back to the controller thread
            ControlCommand control_command = pending_command;
            pthread_mutex_unlock(&control_lock);

            // Reset the command exit code to 0 before processing the command
            int command_exit_code = 0;

            // Determine which command was submitted and perform the relevant actions
            switch (control_command.action) {

                case CONTROL_GETREADY:

                    // Stop polling and ensure the previous operation closed its file
                    poll_meter = 0;
                    if (energy_collection.metrics_file != NULL) {
                        command_exit_code = -1;
                        break;
                    }

                    // Open the metrics file for the current test being performed (NOTE - consider including in metrics file contorl function somehow)
                    energy_collection.metrics_file = fopen(control_command.output_filepath, "w");

                    // Ensure that the metrics file opened successfully
                    if (energy_collection.metrics_file == NULL) {
                        fprintf(stderr, "[ERROR] - Failed to open the metrics file: %s\n", control_command.output_filepath);
                        command_exit_code = -1;
                        break;
                    }

                    // Store the current filepath and polling interval
                    strcpy(energy_collection.output_filepath, control_command.output_filepath);
                    energy_collection.polling_rate = control_command.polling_rate;

                    // Write the baseline before the listener sends READY
                    if (write_energy_reading(meter_device, &energy_collection, 1) != 0 || fflush(energy_collection.metrics_file) != 0) {
                        close_metrics_file(&energy_collection, 1);
                        command_exit_code = -1;
                        break;
                    }

                    // Begin polling once the baseline has been saved
                    poll_meter = 1;
                    break;

                case CONTROL_STOP:

                    // Set poll meter to stop polling
                    poll_meter = 0;

                    // Reject STOP when there is no active operation
                    if (energy_collection.metrics_file == NULL) {
                        command_exit_code = -1;
                        break;
                    }

                    // Take a fresh final reading and close the file before the listener sends SAVED
                    command_exit_code = write_energy_reading(meter_device, &energy_collection, 0);
                    if (close_metrics_file(&energy_collection, command_exit_code != 0) != 0) {
                        command_exit_code = -1;
                    }

                    break;

                case CONTROL_END:

                    // Discard any incomplete measurement and end the session
                    command_exit_code = close_metrics_file(&energy_collection, 1);
                    break;
            
            }

            // Store the command result and wake the listener
            pthread_mutex_lock(&control_lock);
            command_exit_status = command_exit_code;
            command_pending = 0;
            pthread_cond_signal(&control_changed);

            // If the control action is END, break out of the collection loop
            if (control_command.action == CONTROL_END) {
                break;
            }

            // Recheck whether polling is enabled before taking another reading
            continue;

        }

        // Release the control lock and poll the energy meter, saving the results
        pthread_mutex_unlock(&control_lock);
        if (write_energy_reading(meter_device, &energy_collection, 0) != 0) {

            // Discard the measurement and stop if a periodic reading could not be saved
            fprintf(stderr, "[ERROR] - Failed to record a periodic energy reading.\n");
            close_metrics_file(&energy_collection, 1);
            exit(EXIT_FAILURE);

        }

        // Lock the control lock so that shared control variables can be checked during poll wait
        pthread_mutex_lock(&control_lock);

        // Check if a polling interval has been set and if no command is pending, wait before next poll
        if (energy_collection.polling_rate != 0 && command_pending != 1) {

            // Calculate the clock time for the next poll
            struct timespec next_poll_time;
            if (calculate_next_poll_time(energy_collection.polling_rate, &next_poll_time) != 0) {

                // Discard the measurement and stop if the polling interval cannot be maintained
                close_metrics_file(&energy_collection, 1);
                exit(EXIT_FAILURE);

            }

            // Wait until either the next poll time has been reached or command has been submitted (releasing the control lock as well)
            int end_wait = 0;
            while(command_pending != 1 && end_wait == 0){
                end_wait = pthread_cond_timedwait(&control_changed, &control_lock, &next_poll_time);
            }
        
        }

    }

    // Release the control lock before exiting the collection thread
    pthread_mutex_unlock(&control_lock);

    return NULL;

}

//------------------------------------------------------------------------------------------------------------------------------ 
int main(int argc, char *argv[]) {
    /*  Main function for the energy testing collector script. It will handle the initialisation of the collector environment, 
        start the control listener and energy metrics collector threads, and manage the overall flow of the collector script. */

    // If command line arguments are provided, parse them before deciding whether to show the banner
    int display_welcome = 1;
    int prompt_for_result_dir = 1;
    if (argc > 1) {
        parse_args(argc, argv, &display_welcome, &prompt_for_result_dir);
    }

    // Output the welcome message if it has not been disabled
    if (display_welcome) {
        printf("#################################\n");
        printf("PQC-LEO: Energy Testing Collector\n");
        printf("#################################\n\n");
    }

    // Declare the test controller and meter instances
    TestController test_controller;
    MeterDevice meter_device;

    // Setup the collection environment
    if (setup_env(&test_controller, &meter_device, prompt_for_result_dir) != 0) {
        fprintf(stderr, "[ERROR] - Failed to setup the collection environment.\n");
        return -1;
    }

    // Output the current task to the terminal
    printf("\n-------------------------\n");
    printf("Energy Metrics Collection\n");
    printf("-------------------------\n\n");

    // Declare the thread IDs for the control listener and energy metrics collector threads
    pthread_t control_thread, metrics_thread;

    // Start the control listener thread
    if (pthread_create(&control_thread, NULL, control_listener_thread, &test_controller) != 0) {
        fprintf(stderr, "[ERROR] - Failed to create control listener thread.\n");
        controller_close(&test_controller);
        return -1;
    }

    // Start the energy metrics collector thread
    if (pthread_create(&metrics_thread, NULL, collect_energy_metrics_thread, &meter_device) != 0) {
        fprintf(stderr, "[ERROR] - Failed to create metrics collector thread.\n");
        pthread_cancel(control_thread);
        controller_close(&test_controller);
        return -1;
    }

    // Wait for the threads to finish
    pthread_join(control_thread, NULL);
    pthread_join(metrics_thread, NULL);

    // Cleanup and exit
    controller_close(&test_controller);
    return control_failed ? EXIT_FAILURE : EXIT_SUCCESS; // NOTE - MAYBE CHANGE UP

}
