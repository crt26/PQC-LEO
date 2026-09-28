/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

Program for implementing the PQC-LEO computational energy benchmarking tool.
It configures the control channel to the energy collector, gathers test run
options from the user, performs a baseline measurement, and executes KEM and
signature benchmarking loops across the available liboqs algorithms. During
execution, it coordinates GETREADY, START, and STOP control messaging for each
test phase and manages liboqs initialisation and shutdown.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <getopt.h>
#include "comp_energy_tester.h"

// Define the global flag variables
int custom_net_ports = 0;

//------------------------------------------------------------------------------------------------------------------------------ 
void output_help() {
    /*  Function for outputting the help message for the comp_energy_tester program. It will display the usage, options, and their 
        descriptions. */

    // Print the help message
    printf("Usage: comp_energy_tester [OPTIONS]\n\n");
    printf("Options:\n");
    printf("-c, --use-custom-net-control-ports   Use custom network control ports for energy testing control signalling\n");
    printf("-s, --skip-welcome-message           Skip the welcome message on startup (useful for automated calling of the script)\n");
    printf("-h, --help                           Display the help message and exit\n");

}

//------------------------------------------------------------------------------------------------------------------------------ 
void parse_args(int argc, char *argv[], int *display_welcome) {
    /*  Function for parsing the command line arguments passed to the comp_energy_tester program. The function will parse the 
        arguments and set the appropriate flags and values. If an error is encountered, the function will display an error
        message and the help message before exiting. */

    // Define the getopt_long struct and options
    struct option long_options[] = {
        {"use-custom-net-control-ports", no_argument, 0, 'c'},
        {"skip-welcome-message", no_argument, 0, 's'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    // Declare the option and index variables
    int option;
    int option_index = 0;

    // Parse the command line arguments
    while((option = getopt_long(argc, argv, "chs", long_options, &option_index)) != -1) {

        // Determine which option is being processed
        switch (option) {

            case 'c':
            
                // Set the custom network control ports flag to true
                custom_net_ports = 1;
                break;

            case 's':

                // Set the display welcome flag to false
                *display_welcome = 0;
                break;

            case 'h':

                // Output the help message and return success
                output_help();
                exit(0);

            default:

                // Output an error message for an unknown argument and present the help message before exiting
                fprintf(stderr, "[ERROR] - Unknown command line argument: %s\n", argv[optind - 1]);
                output_help();
                exit(1);

        }

    }

}

//-------------------------------------------------------------------------------------------------------------------------------
int int_checker(char *input, int *int_param, char *param_name) {
    /* Helper function for validating integer inputs */

    // Loop through the input buffer to check if each index is a digit
    int is_valid = 1;
    for (int index = 0; input[index] != '\0'; index++) {

        // Check if the current value is a valid digit
        if (!isdigit((unsigned char)input[index])) {
            is_valid = 0;
            break;
        }

    }

    // Ensure that the input is valid
    if (is_valid != 1 || strlen(input) == 0) {
        printf("[WARNING] - Invalid value for number of %s, please enter a valid integer\n", param_name);
        return -1;
    }

    // Convert the input to a int
    *int_param = atoi(input);

    // Check that the value is above 0
    if (*int_param < 0) {
        printf("[WARNING] - The number of %s must be above 0\n", param_name);
        return -1;
    }

    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------ 
int configure_controller(TestController *test_controller) {
    /*  Function to configure the test controller used for sending and receiving control signals. It handles the selection of 
        the control communication method, the configuration of the controller settings, and the initialisation of the 
        controller. */

    // Output the current task to the terminal
    printf("-----------------------------\n");
    printf("Test Controller Configuration\n");
    printf("-----------------------------\n\n");

    // Loop until a valid control method is selected by the user
    while (1) {

        // Prompt the user for the control method to use and read the input from stdin
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

    // Determine which control method has been selected and perform configuration steps
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

        // Check if a serial port name was returned
        if (control_port_name == NULL) {
            fprintf(stderr, "[ERROR] - No serial ports are available, please verify connectivity\n");
            free(control_port_name);
            exit(1);
        }

        // Store the serial port name in the serial controller instance
        test_controller->serial_controller.control_port_name = control_port_name;

        // Initialise the serial controller
        if (controller_init(test_controller) != 0) {
            fprintf(stderr, "[ERROR] - Failed to initialise the serial controller\n");
            free(control_port_name);
            return -1;
        }

        // Free the serial port name
        free(control_port_name);
        printf("\n");

        return 0;

    }
    else if (strcmp(test_controller->control_type, "network") == 0) {

        /*Insert here future prompt to ask whether to use UDP or TCP when TCP is supported*/

        // Define the default local and remote port numbers to be used for the network controller
        int local_port = 26001;
        int remote_port = 26000;

        // Create the vars to store the local and remote ip address settings
        char local_ip[16];
        char remote_ip[16];

        // Get the local and remote IP addresses to be used for the network controller
        printf("Configure the local device listening IP:\n");
        get_ip_address(local_ip, sizeof(local_ip));
        printf("\n");

        printf("Configure the remote device listening IP:\n");
        get_ip_address(remote_ip, sizeof(remote_ip));
        printf("\n");

        // Determine if the user needs to be prompted for the custom local and remote control port numbers
        if (custom_net_ports == 1) {

            // Prompt the user for the local port number until a available port is provided
            printf("Configure the local device listening port:\n");
            while (1) {

                // Prompt the user for the local port number and store it in the local_port variable
                get_port_number(&local_port);

                // Check if the provided local port number is available for use
                if (check_port_availability(local_port, "UDP") == 0) {
                    break;
                }
                else {
                    fprintf(stderr, "[ERROR] - The provided local port %d is not available on the system for use in the network controller\n", local_port);
                }

            }
            printf("\n");

            // Prompt the user for the remote port number until a valid port is provided
            printf("Configure the remote device listening port:\n");
            get_port_number(&remote_port);
            printf("\n");

        }

        // If using the default local port number, check if it is available before proceeding with the network controller configuration
        if (custom_net_ports == 0) {
            if (check_port_availability(local_port, "UDP") != 0) {
                fprintf(stderr, "[ERROR] - The default local port %d is not available on the system for use in the network controller\n", local_port);
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
            fprintf(stderr, "[ERROR] - Failed to initialise the network controller\n");
            return -1;
        }

        return 0;

    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
void get_test_options(TestParams *test_params) {
    /*  Function for getting the testing options from the user via command line input. It will populate the provided TestParams 
        struct with the relevant values. */

    // Output the current task to the terminal
    printf("-------------------------------\n");
    printf("Configure the test parameters\n");
    printf("-------------------------------\n\n");

    // Define the test param variables
    int iterations;
    int test_runs;

    // Declare the input buffer
    char input[16];

    // Loop until a valid number of iterations is received from the user
    while (1) {

        // Prompt the user for the number of test iterations to perform
        printf("Enter the number of iterations for each test (e.g., 1000): ");
        fgets(input, sizeof(input), stdin);

        // Remove the trailing newline character
        input[strcspn(input, "\n")] = '\0';

        // Check if input is a valid int
        if (int_checker(input, &iterations, "iterations") != 0) {
            continue;
        }

        // Ensure that the number of iterations is above 0
        if (iterations <= 0) {
            printf("[WARNING] - The number of iterations must be above 0\n");
            continue;
        }

        // Assign the iterations value to test_params
        test_params->iterations = iterations;
        break;

    }

    // Loop until a valid number of test runs is received from the user
    while (1) {

        // Prompt the user for the number of test runs to perform
        printf("Enter the number of test runs to perform: ");
        fgets(input, sizeof(input), stdin);

        // Remove trailing newline character
        input[strcspn(input, "\n")] = '\0';

        // Check if input is a valid int
        if (int_checker(input, &test_runs, "testing runs") != 0) {
            continue;
        }

        // Ensure that the number of test runs is above 0
        if (test_runs <= 0) {
            printf("[WARNING] - The number of test runs must be above 0\n");
            continue;
        }

        // Assign the number of runs to test_params
        test_params->total_runs = test_runs;
        break;

    }

    // Loop until a valid polling rate is received from the user
    float captured_polling_rate;
    while (1) {

        // Prompt the user for the energy meter polling rate to be used during testing
        printf("Enter the energy meter polling rate in milliseconds (0 for no delays between polls): ");
        fgets(input, sizeof(input), stdin);

        // Remove trailing newline character
        input[strcspn(input, "\n")] = '\0';

        // Reject negative values before conversion so inputs such as "-0" are not accepted as zero
        char *polling_rate_start_ptr = input;
        while (*polling_rate_start_ptr != '\0' && isspace((unsigned char)*polling_rate_start_ptr)) {
            polling_rate_start_ptr++;
        }

        if (*polling_rate_start_ptr == '-') {
            printf("[WARNING] - Invalid polling rate. It must be a positive float or 0 for no delays between polls.\n");
            continue;
        }

        // Convert the input to a float and validate that the entire input is numeric
        char *polling_rate_end_ptr = NULL;
        captured_polling_rate = strtof(polling_rate_start_ptr, &polling_rate_end_ptr);

        // Skip trailing whitespace after the parsed number
        while (*polling_rate_end_ptr != '\0' && isspace((unsigned char)*polling_rate_end_ptr)) {
            polling_rate_end_ptr++;
        }

        // Ensure a value was parsed and no invalid trailing characters remain
        if (polling_rate_end_ptr == polling_rate_start_ptr || *polling_rate_end_ptr != '\0') {
            printf("[WARNING] - Invalid polling rate. Please enter a positive number or 0.\n");
            continue;
        }

        // Check if the input is a valid positive float or 0
        if (captured_polling_rate < 0.0f) {
            printf("[WARNING] - Invalid polling rate. It must be a positive float or 0 for no delays between polls.\n");
            continue;
        }

        // Assign the polling rate to test_params
        test_params->polling_rate = captured_polling_rate;
        break;

    }

    // Add newline for formatting
    printf("\n");

}

//-------------------------------------------------------------------------------------------------------------------------------
void get_baseline(TestController *test_controller, TestParams *test_params) {
    /*  Function for performing the baseline energy measurements. This function will initialise the test parameters and send 
        the necessary control messages to the collector so that a baseline measurement can be taken before the actual tests 
        begin. */

    // Output the current task to the terminal
    printf("Gathering Baseline Energy Measurements...\n");

    // Allocate memory for the baseline_params struct
    TestParams *baseline_params = malloc(sizeof(TestParams));
    if (baseline_params == NULL) {
        fprintf(stderr, "[ERROR] - Failed to allocate memory for baseline_params.\n");
        return;
    }

    // Prepare test_params for the baseline measurement
    baseline_params->control_type = 1;
    baseline_params->test_type = "comp_baseline";
    baseline_params->test_algs = "baseline";
    baseline_params->run_num = 1;
    baseline_params->polling_rate = test_params->polling_rate;

    // Send the GETREADY message to the server
    if (control_handler(test_controller, baseline_params) != 0) {
        fprintf(stderr, "[ERROR] - Failed to send GETREADY for baseline measurement.\n");
        free(baseline_params);
        return;
    }

    // Sleep to allow baseline measurement to be taken
    sleep(10);

    // Send the stop command to end the baseline measurement
    baseline_params->control_type = 2;
    control_handler(test_controller, baseline_params);

    // Free the baseline_params struct
    free(baseline_params);

    // Output the completion message to the terminal
    printf("Baseline energy measurements completed\n\n");

}

//-------------------------------------------------------------------------------------------------------------------------------
int test_kem(const char *method_name, TestController *test_controller, TestParams *test_params) {
    /*  Function for testing a specific KEM algorithm. This function will initialise the KEM, allocate memory for the required 
        variables, and perform the key generation, encapsulation, and decapsulation tests. */

    // Declare the Liboqs KEM and key variables
	OQS_KEM *kem = NULL;
	uint8_t *public_key = NULL;
	uint8_t *secret_key = NULL;
	uint8_t *ciphertext = NULL;
	uint8_t *shared_secret_e = NULL;
	uint8_t *shared_secret_d = NULL;

    // Initialise the KEM
	kem = OQS_KEM_new(method_name);
	if (kem == NULL) {
		return -1;
	}

    // Allocate memory for the key variables
	public_key = OQS_MEM_malloc(kem->length_public_key);
	secret_key = OQS_MEM_malloc(kem->length_secret_key);
	ciphertext = OQS_MEM_malloc(kem->length_ciphertext);
	shared_secret_e = OQS_MEM_malloc(kem->length_shared_secret);
	shared_secret_d = OQS_MEM_malloc(kem->length_shared_secret);

    // Ensure that memory allocation was successful
	if ((public_key == NULL) || (secret_key == NULL) || (ciphertext == NULL) || (shared_secret_e == NULL) || (shared_secret_d == NULL)) {
		fprintf(stderr, "ERROR: OQS_MEM_malloc failed\n");
		return -1;
	}

    // Perform one time test of each operation to ensure no errors occur
    if (OQS_KEM_keypair(kem, public_key, secret_key) != OQS_SUCCESS) {
        fprintf(stderr, "ERROR: OQS_KEM_keypair failed\n");
        return -1;
    }

    if (OQS_KEM_encaps(kem, ciphertext, shared_secret_e, public_key) != OQS_SUCCESS) {
        fprintf(stderr, "ERROR: OQS_KEM_encaps failed\n");
        return -1;
    }

    if (OQS_KEM_decaps(kem, shared_secret_d, ciphertext, secret_key) != OQS_SUCCESS) {
        fprintf(stderr, "ERROR: OQS_KEM_decaps failed\n");
        return -1;
    }

    // Assign the alg name to the test params struct
    test_params->test_algs = kem->method_name;

    /*---Keygen testing---*/

    // Output the current algorithm/operation being tested to the terminal
    printf("Testing KEM %s - Keygen\n", kem->method_name);

    // Get ready for the test
    test_params->control_type = 1;
    test_params->test_type = "comp_kem_keygen";
    control_handler(test_controller, test_params);

    // Perform the keygen test for the specified iterations
    for (int i = 0; i < test_params->iterations; i++) {
        OQS_KEM_keypair(kem, public_key, secret_key);
    }

    // Send stop command after keypair generation test
    test_params->control_type = 2;
    control_handler(test_controller, test_params);

    /*---Encapsulation testing---*/

    // Output the current algorithm/operation being tested to the terminal
    printf("Testing KEM %s - Encaps\n", kem->method_name);

    // Get ready for encaps test
    test_params->control_type = 1;
    test_params->test_type = "comp_kem_encaps";
    control_handler(test_controller, test_params);

    // Perform the encaps test for the specified iterations
    for (int i = 0; i < test_params->iterations; i++) {
        OQS_KEM_encaps(kem, ciphertext, shared_secret_e, public_key);
    }

    // Send stop command after encaps
    test_params->control_type = 2;
    control_handler(test_controller, test_params);

    /*---Decapsulation testing---*/

    // Output the current algorithm/operation being tested to the terminal
    printf("Testing KEM %s - Decaps\n", kem->method_name);

    // Get ready for decaps test
    test_params->control_type = 1;
    test_params->test_type = "comp_kem_decaps";
    control_handler(test_controller, test_params);

    // Perform the decaps test for the specified iterations
    for (int i = 0; i < test_params->iterations; i++) {
        OQS_KEM_decaps(kem, shared_secret_d, ciphertext, secret_key);
    }

    // Send the stop command after decaps
    test_params->control_type = 2;
    control_handler(test_controller, test_params);

    // Perform the clean up operations
    if (kem != NULL) {
        OQS_MEM_secure_free(secret_key, kem->length_secret_key);
        OQS_MEM_secure_free(shared_secret_e, kem->length_shared_secret);
        OQS_MEM_secure_free(shared_secret_d, kem->length_shared_secret);
    }
    OQS_MEM_insecure_free(public_key);
    OQS_MEM_insecure_free(ciphertext);
    OQS_KEM_free(kem);

    return 0;
    
}

//-------------------------------------------------------------------------------------------------------------------------------
int test_sig(const char *method_name, TestController *test_controller, TestParams *test_params) {
    /*  Function for testing a specific SIG algorithm. This function will initialise the SIG, allocate memory for the required 
        variables, and perform the key generation, signing, and verification tests. */

    // Declare the Liboqs signature and key variables
	OQS_SIG *sig = NULL;
	uint8_t *public_key = NULL;
	uint8_t *secret_key = NULL;
	uint8_t *message = NULL;
	uint8_t *signature = NULL;
	size_t message_len = 50;
	size_t signature_len = 0;

    // Initialise the signature
	sig = OQS_SIG_new(method_name);
	if (sig == NULL) {
		return -1;
	}

    // Allocate memory for the key variables
	public_key = OQS_MEM_malloc(sig->length_public_key);
	secret_key = OQS_MEM_malloc(sig->length_secret_key);
	message = OQS_MEM_malloc(message_len);
	signature = OQS_MEM_malloc(sig->length_signature);

    // Ensure that memory allocation was successful
	if ((public_key == NULL) || (secret_key == NULL) || (message == NULL) || (signature == NULL)) {
		fprintf(stderr, "ERROR: OQS_MEM_malloc failed\n");
		return -1;
	}

    // Generate a random message to sign
	OQS_randombytes(message, message_len);

    // Perform one time test of each operation to ensure no errors occur
    if (OQS_SIG_keypair(sig, public_key, secret_key) != OQS_SUCCESS) { 
        fprintf(stderr, "ERROR: OQS_SIG_keypair failed\n");
        return -1;
    }

    if (OQS_SIG_sign(sig, signature, &signature_len, message, message_len, secret_key) != OQS_SUCCESS) {
        fprintf(stderr, "ERROR: OQS_SIG_sign failed\n");
        return -1;
    }

    if (OQS_SIG_verify(sig, message, message_len, signature, signature_len, public_key) != OQS_SUCCESS) {
        fprintf(stderr, "ERROR: OQS_SIG_verify failed\n");
        return -1;
    }

    // Assign the alg name to the test params struct
    test_params->test_algs = sig->method_name;

    /*---Keygen testing---*/

    // Output the current algorithm/operation being tested to the terminal
    printf("Testing SIG %s - Keygen\n", sig->method_name);

    // Get ready for the test
    test_params->control_type = 1;
    test_params->test_type = "comp_sig_keygen";
    control_handler(test_controller, test_params);

    // Perform the keygen test for the specified iterations
    for (int i = 0; i < test_params->iterations; i++) {
        OQS_SIG_keypair(sig, public_key, secret_key);
    }

    // Send stop command after keypair generation test
    test_params->control_type = 2;
    control_handler(test_controller, test_params);

    /*---Signing testing---*/

    // Output the current algorithm/operation being tested to the terminal
    printf("Testing SIG %s - Sign\n", sig->method_name);

    // Get ready for sign test
    test_params->control_type = 1;
    test_params->test_type = "comp_sig_sign";
    control_handler(test_controller, test_params);

    // Perform the sign test for the specified iterations
    for (int i = 0; i < test_params->iterations; i++) {
        OQS_SIG_sign(sig, signature, &signature_len, message, message_len, secret_key);
    }

    // Send stop command after sign
    test_params->control_type = 2;
    control_handler(test_controller, test_params);

    /*---Verification testing---*/

    // Output the current algorithm/operation being tested to the terminal
    printf("Testing SIG %s - Verify\n", sig->method_name);

    // Get ready for verify test
    test_params->control_type = 1;
    test_params->test_type = "comp_sig_verify";
    control_handler(test_controller, test_params);

    // Perform the verify test for the specified iterations
    for (int i = 0; i < test_params->iterations; i++) {
        OQS_SIG_verify(sig, message, message_len, signature, signature_len, public_key);
    }

    // Send the stop command after verify
    test_params->control_type = 2;
    control_handler(test_controller, test_params);

    // Perform the cleanup operations
	if (sig != NULL) {
		OQS_MEM_secure_free(secret_key, sig->length_secret_key);
	}
	OQS_MEM_insecure_free(public_key);
	OQS_MEM_insecure_free(signature);
	OQS_MEM_insecure_free(message);
	OQS_SIG_free(sig);

	return 0;

}

//------------------------------------------------------------------------------------------------------------------------------
int test_handler(TestController *test_controller) {
    /*  Function for handling the overall testing process. This function will get the testing options, perform the baseline 
        measurement, and then iterate through the available algorithms to perform the tests. */
    
    // Declare instance of the test params struct
    TestParams test_params;

    // Initialise the test params values
    test_params = (TestParams){
        .control_type = 0,
        .test_type = NULL,
        .test_algs = NULL,
        .iterations = 1000,
        .run_num = 0,
        .polling_rate = 0.0f,
    };

    // Get the testing options from the user and populate the test_params struct
    get_test_options(&test_params);

    // Output the current task to the terminal
    printf("-------------------------\n");
    printf("Performing Energy Testing\n");
    printf("-------------------------\n\n");

    // Get the energy measurement baseline
    get_baseline(test_controller, &test_params);

    // Initialise Liboqs
    int ret;
	OQS_init();

    // Perform the tests for the total number of test runs
    for (int current_run = 1; current_run <= test_params.total_runs; current_run++) {

        // Output the test run information
        printf("------------------------\n");
        printf("Starting test run %d of %d\n", current_run, test_params.total_runs);
        printf("------------------------\n");

        // Update the current run number in the test params struct
        test_params.run_num = current_run;

        // Iterate through the available KEM algorithms and perform tests
        for (size_t i = 0; i < OQS_KEM_algs_length; i++) {
            ret = test_kem(OQS_KEM_alg_identifier(i), test_controller, &test_params);
            if (ret != 0) {
                ret = EXIT_FAILURE;
            }
        }

        // Iterate through the available SIG algorithms and perform tests
        for (size_t i = 0; i < OQS_SIG_algs_length; i++) {
            ret = test_sig(OQS_SIG_alg_identifier(i), test_controller, &test_params);
            if (ret != 0) {
                ret = EXIT_FAILURE;
            }
        }

    }

    // Output testing complete message to the terminal
    printf("\nAll testing runs completed\n");
    printf("Energy usage results will be stored in the selected results directory on the collector machine\n");

    // Send the test END signal to the collector
    test_params.control_type = 3;
    control_handler(test_controller, &test_params);

    return 0;

}

//------------------------------------------------------------------------------------------------------------------------------
int main(int argc, char *argv[]) {
    /*  Main function for the PQC-LEO PQC Computational Energy Tester. This function will initialise the test environment, 
        configure the test controller, and then run the overall testing process. */

    // Parse command line arguments if any are provided to the script
    int display_welcome = 1;
    if (argc > 1) {
        parse_args(argc, argv, &display_welcome);
    }

    // Output the welcome message
    if (display_welcome) {
        printf("###############################\n");
        printf("PQC Computational Energy Tester\n");
        printf("###############################\n\n");
    }

    // Declare the Test controller instance
    TestController test_controller;

    // Configure the test controller and initialise the device
    if (configure_controller(&test_controller) != 0) {
        fprintf(stderr, "[ERROR] - Failed to setup the environment.\n");
        return -1;
    }

    // Initialise the Liboqs library
    OQS_init();

    // Run the test handler
    test_handler(&test_controller);

    // Close the Liboqs library
    OQS_destroy();

    return 0;

}
