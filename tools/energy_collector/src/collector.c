/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO energy metric collector. It configures control signalling
(serial or network), initialises the connected meter device, manages results storage, and runs
threaded listeners for test control commands and energy metric polling. During execution, it
handles GETREADY/START/STOP/END commands, writes sampled power data to per-test output files,
and coordinates clean shutdown of controller and collection resources.

*/

#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <pthread.h>
#include <getopt.h>
#include <time.h>
#include "collector.h"

// Declare shared thread variables
pthread_mutex_t control_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t control_changed = PTHREAD_COND_INITIALIZER;
int start_flag;
int end_flag;
pthread_mutex_t file_lock = PTHREAD_MUTEX_INITIALIZER;
FILE *metrics_file;

// Declare the global variables used throughout the collector script
static char results_dir[256];
int skip_poll_sleep = 0;
useconds_t polling_rate;
int custom_net_ports = 0;

//------------------------------------------------------------------------------------------------------------------------------ 
void output_help() {
    /*  Function for outputting the help message for the collector script. It will display the usage, options, and their 
        descriptions. After this, it will exit the program. */

    // Print the help message
    printf("Usage: collector [OPTIONS]\n");
    printf("Options:\n");
    printf("-d, --results-dir=<dir>                 Specify the directory to store results in (if not provided, will prompt for it during setup)\n");
    printf("-s, --skip-welcome-message              Skip the welcome message on startup (useful for automated calling of the script)\n");
    printf("-c, --use-custom-net-control-ports      Use custom network control ports for energy testing control signalling\n");
    printf("-h, --help                              Display this help message and exit\n");

    exit(0);

}

//------------------------------------------------------------------------------------------------------------------------------ 
void parse_args(int argc, char *argv[], int *display_welcome, int *prompt_for_result_dir) {
    /*  Function for parsing the command line arguments passed to the control sender script. */
    
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

        // Get the com port to be used for the serial controller
        printf("Please select the com port for serial control signals:\n");
        char *control_port_name =  list_com_ports();

        // Check if a control port name was returned
        if (control_port_name == NULL) {
            fprintf(stderr, "[ERROR] - No com ports are available, please verify connectivity\n");
            free(control_port_name);
            exit(1);
        }

        // Store the control port name in the serial controller instance
        test_controller->serial_controller.control_port_name = control_port_name;

        // Initialise the the serial controller
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

        /*Insert here future prompt to ask wether to use UDP or TCP when TCP is supported*/

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

    // Calculate the number of available meter type options based on the size of the meter_type_options array
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

        // Reading the user and convert to a integer
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

    // Get the com port to be used for the energy meter device
    printf("Please select the com port for communicating with the energy meter device:\n\n");
    char *control_port_name = list_com_ports();

    // Check if a control port name was returned
    if (control_port_name == NULL) {
        fprintf(stderr, "[ERROR] - No com ports are available, please verify connectivity\n");
        free(control_port_name);
        exit(1);
    }

    // Initialise the energy meter device with the selected com port
    if (meter_init(meter_device, selected_meter_type, control_port_name) != 0) {
        fprintf(stderr, "[ERROR] - Failed to initialise the energy meter device.\n");
        free(control_port_name);
        return -1;
    }

    // Free the meter com port name
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

//-------------------------------------------------------------------------------------------------------------------------------
int get_ready_parser(char *message) {
    /*  Function for handling the GETREADY message received from the control port. It will parse the message and prepare the 
        collector for energy testing. This includes extracting relevant parameters, and initialising the metrics file for 
        writing within the collect_metrics thread. */

    // Declare the message elements array and its size
    char *message_elements[4];
    size_t array_size = sizeof(message_elements);

    // Initialise the message elements array with NULL pointers
    for (size_t i = 0; i < sizeof(message_elements) / sizeof(message_elements[0]); i++) {
        message_elements[i] = NULL;
    }

    // Parse the received message to extract the test parameters
    if (message_parser(message, "GETREADY", message_elements, array_size) != 0) {
        fprintf(stderr, "[ERROR] - Failed to parse the GETREADY message.\n");
        return -1;
    }
        
    // Create the filename based on the testing parameters received
    char filename[256];
    snprintf(filename, sizeof(filename), "%s_%s_%s.txt", message_elements[0], message_elements[1], message_elements[2]);

    // Set the filepath to the results directory
    char filepath[512];
    snprintf(filepath, sizeof(filepath), "%s/%s", results_dir, filename);

    // Extract the polling rate from the message elements and store it in the global variable
    float captured_polling_rate = strtof(message_elements[3], NULL);
    if (captured_polling_rate < 0.0f) {
        fprintf(stderr, "[ERROR] - Invalid polling rate received in GETREADY message: %s\n", message_elements[3]);
        return -1;
    }

    // Determine if the polling rate is set to 0 indicating that the collector should skip sleeping between polls
    if (captured_polling_rate == 0.0f) {
        skip_poll_sleep = 1;
    }
    else {
        skip_poll_sleep = 0;
    }

    // Convert the polling rate from miliseconds to microseconds and store it in the global variable
    if (skip_poll_sleep == 0) {
        polling_rate = (useconds_t)(captured_polling_rate * 1000.0f);
    }

    // Free the message elements
    for (size_t i = 0; i < sizeof(message_elements) / sizeof(message_elements[0]); i++) {
        if (message_elements[i] != NULL) {
            free(message_elements[i]);
        }
    }

    // Open the target results file for writing the energy metrics to
    metrics_file = fopen(filepath, "w");
    if (metrics_file == NULL) {
        fprintf(stderr, "[ERROR] - Failed to open the metrics file: %s\n", filepath);
        return -1;
    }

    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------ 
void *control_listener_thread(void *arg) {
    /*  Function for handling the control listener thread that listens for control commands from the control port. 
        It will detect GETREADY, START, STOP, and END commands and set the relevant shared thread flag values used by the
        energy collection thread depending on the received command. */

    // Cast the argument to TestController type
    TestController *test_controller = (TestController *)arg;

    // Declare the message buffer and ready message
    char ready_message[] = "READY\n";
    printf("[NOTICE] - Waiting for first connection...\n");

    // Loop to handle control signalling until testing is complete
    while (1) {

        // Reset the message buffer
        char msg_buffer[256];

        // Wait for the command signal from the controller
        if (controller_receive(test_controller, msg_buffer, sizeof(msg_buffer)) != 0) {
            fprintf(stderr, "[ERROR] - Failure in the serial controller receiver.\n");
            pthread_exit(NULL);
        }

        // Determine which command action to perform based on the received message
        if (strstr(msg_buffer, "GETREADY") != NULL) {

            // Output the received GETREADY message
            printf("[NOTICE] - Received GETREADY message: %s\n", msg_buffer);

            // Call the get_ready_parser to prepare for the energy metric collection
            if (get_ready_parser(msg_buffer) != 0) {
                fprintf(stderr, "[ERROR] - Failure in the get_ready_parser.\n");
                pthread_exit(NULL);
            }

            // Give the sender time to get ready for receiving the READY message
            usleep(250000);
            printf("[NOTICE] - Sending READY message back to the control port...\n");

            // Send a confirmation message back to the testing device that collector is ready for testing
            controller_send(test_controller, ready_message);

        } else if (strcmp(msg_buffer, "START") == 0) {

            // Lock the start flag mutex and set the start flag
            pthread_mutex_lock(&control_lock);
            start_flag = 1;
            pthread_cond_signal(&control_changed);
            pthread_mutex_unlock(&control_lock);

            // Print that the start message was received
            printf("[NOTICE] - Received START command, beginning energy metrics collection...\n");
        
        } else if (strcmp(msg_buffer, "STOP") == 0) {

            // Lock the start flag mutex and clear the start flag
            pthread_mutex_lock(&control_lock);
            start_flag = 0;
            pthread_mutex_unlock(&control_lock);

            // Lock the file mutex and then close the current metrics file
            pthread_mutex_lock(&file_lock);
            if (metrics_file) {
                fclose(metrics_file);
                metrics_file = NULL;
            }
            pthread_mutex_unlock(&file_lock);

            // Print that the stop message was received
            printf("[NOTICE] - Received STOP command, stopping energy metrics collection...\n\n");

        } else if (strcmp(msg_buffer, "END") == 0) {
            
            // Lock the start and end flags mutexes and set the flags
            pthread_mutex_lock(&control_lock);
            start_flag = 0;
            end_flag = 1;
            pthread_cond_signal(&control_changed);
            pthread_mutex_unlock(&control_lock);

            // Lock the file mutex and then close the current metrics file
            pthread_mutex_lock(&file_lock);
            if (metrics_file) {
                fclose(metrics_file);
                metrics_file = NULL;
            }
            pthread_mutex_unlock(&file_lock);

            // Print that the end message was received
            printf("[NOTICE] - Received END command, ending energy metrics collection...\n\n");

            // Exit the thread to stop further processing
            pthread_exit(NULL);
            
        } else {

            // Output the error message to the terminal
            fprintf(stderr, "[ERROR] - Unknown command received: %s\n", msg_buffer);
            exit(1);

        }

    }

    pthread_exit(NULL);

}

//------------------------------------------------------------------------------------------------------------------------------
void *collect_energy_metrics_thread(void *arg) {
    /*  Function for handling the energy metrics collection thread that polls the energy meter device for usage metrics and 
        writes them to the metrics file. It will run until the end flag is set by the control listener thread. */

    // Cast the argument to TestController type
    MeterDevice *meter_device = (MeterDevice *)arg;

    // Declare the meter reading data struct
    MeterReading meter_reading;

    // Define the start value holding variables
    int first_reading = 1;
    unsigned int start_mAh = 0;
    unsigned int start_mWh = 0;
    struct timespec start_time = {0};
    struct timespec current_time = {0};
     
    // Loop to handle energy metrics collection until testing is complete
    while (1) {

        // Lock the control mutex to check the start and end flags
        pthread_mutex_lock(&control_lock);

        // Wait until the start flag is set or the end flag is set, resseting the first reading flag
        while (!start_flag && !end_flag) {
            first_reading = 1;
            pthread_cond_wait(&control_changed, &control_lock);
        }

        // Capture the current state of the start and end flags to use outside of the mutex lock
        int local_start_flag = start_flag;
        int local_end_flag = end_flag;

        // Release lock before polling device
        pthread_mutex_unlock(&control_lock);

        // If the end flag is set, exit the thread immediately
        if (local_end_flag) {
            break;
        }

        // Check if energy metric collection should begin
        if (local_start_flag) {

            // Poll the meter device for energy metrics
            meter_poll(meter_device, &meter_reading);

            // Set values for the first reading to be used in further calculations
            if (first_reading) {

                // Store the initial run values and set start time
                start_mAh = meter_reading.mAh;
                start_mWh = meter_reading.mWh;
                clock_gettime(CLOCK_MONOTONIC, &start_time);

                // Flip the first reading flag to indicate inital run values captured
                first_reading = 0;

            }

            // Calculate elapsed time in milliseconds since the first sample
            clock_gettime(CLOCK_MONOTONIC, &current_time);
            double elapsed_time_ms = (double)(current_time.tv_sec - start_time.tv_sec) * 1000.0 + (double)(current_time.tv_nsec - start_time.tv_nsec) / 1000000.0;

            // Calculate correct mah and mwh values based on the first reading
            unsigned int display_mWh = meter_reading.mWh - start_mWh;
            unsigned int display_mAh = meter_reading.mAh - start_mAh;

            // Calculate the joules consumed based on the mWh value
            float joules = (float)display_mWh * 3.6f;

            // Lock the file mutex before writing to the file
            pthread_mutex_lock(&file_lock);
            if (metrics_file) {

                // Write out the current metrics poll to the file
                fprintf(
                    metrics_file,
                    "Voltage: %.2f V | Current: %.2f A | Power: %.2f W | mWh: %u | mAh: %u | Joules: %.2f | Elapsed Time: %f ms\n",
                    meter_reading.voltage, meter_reading.current, meter_reading.power, display_mWh, display_mAh, joules, elapsed_time_ms
                );

            }

            // Unlock the file mutex
            pthread_mutex_unlock(&file_lock);

            // Perform set sleep to control the polling rate if needed
            if (skip_poll_sleep == 0) {
                usleep(polling_rate);
            }

        }
        
    }

    pthread_exit(NULL);

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
    return 0;

}