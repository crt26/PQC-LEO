"""
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

TLS handshake transmission-cost testing script for PQC-LEO. This script runs OpenSSL TLS 1.3
handshake tests across PQC, Hybrid-PQC, and classical algorithm types. It tests PQC and Hybrid-PQC
signature/KEM pairs and classical signature/key-exchange-group/ciphersuite combinations. For each
combination, the script executes both one-way and mutual-authentication handshakes, extracts the
transmitted byte counts from the OpenSSL client output, and structures the results into clean CSV files.

Before running tests, the script checks that required key/certificate and algorithm-list files
are present, resolves the project root from the marker file, and sets the OpenSSL library path
needed for execution. Results are written to machine-specific CSV files in the TLS handshake
bytes results directory, split by algorithm category.
"""

#------------------------------------------------------------------------------------------------------------------------------
import os
import subprocess
import sys
import re
import pandas
import shutil
import socket

# Set the OpenSSL executable path variable
openssl_bin = ""

# Define the global IP address and port numbers for the OpenSSL s_server and s_client processes
SERVER_ADDRESS = "127.0.0.1"
SERVER_PORT = 4433
SERVER_ENDPOINT = f"{SERVER_ADDRESS}:{SERVER_PORT}"

#------------------------------------------------------------------------------------------------------------------------------
def setup_base_env():
    """ Function for setting up the base testing environment. This includes determining the project root directory, defining 
        the core filepaths, and reading in the algorithm lists files. The function returns two dictionaries: one containing 
        the core filepaths and the other containing the algorithm lists. """

    global openssl_bin

    # Determine the directory that the script is being executed from and set the marker filename
    script_dir = os.path.dirname(os.path.abspath(__file__))
    current_dir = script_dir
    marker_filename = ".pqc_leo_dir_marker.tmp"

    # Continue moving up the directory tree until the .pqc_leo_dir_marker.tmp file is found
    while True:

        # Check if the .pqc_leo_dir_marker.tmp file is present
        if os.path.isfile(os.path.join(current_dir, marker_filename)):
            root_dir = current_dir
            break

        # Move up a directory and store the new path
        current_dir = os.path.dirname(current_dir)

        # If the system's root directory is reached and the file is not found, exit the script
        if current_dir == "/":
            print("[ERROR] - Root directory path file not present, please ensure the path is correct and try again.")
            sys.exit(1)

    # Define the core filepaths based on the detected root_dir path
    dir_paths = {
        "root_dir": root_dir,
        "test_data_dir": os.path.join(root_dir, "test_data"),
        "alg_list_dir": os.path.join(root_dir, "test_data", "alg_lists"),
        "keys_dir": os.path.join(root_dir, "test_data", "keys"),
        "classic_keys_dir": os.path.join(root_dir, "test_data", "keys", "classic"),
        "pqc_keys_dir": os.path.join(root_dir, "test_data", "keys", "pqc"),
        "hybrid_keys_dir": os.path.join(root_dir, "test_data", "keys", "hybrid"),
        "openssl_path": os.path.join(root_dir, "lib", "openssl_4.0.3"),
        "oqs_provider_path": os.path.join(root_dir, "lib", "oqs_provider")
    }

    # Ensure that main key directory is present before proceeding
    if not os.path.isdir(dir_paths["keys_dir"]):
        print("[ERROR] - The keys directory has not been generated, please run the 'tls_generate_keys.sh' script")
        sys.exit(1)

    # Ensure that each alg type key directory is present and not empty before proceeding
    for key_dir_type in ["classic", "pqc", "hybrid"]:

        # Check if the directory itself exists 
        if not os.path.isdir(dir_paths[f"{key_dir_type}_keys_dir"]):
            print(f"[ERROR] - Missing the key directory {key_dir_type}, please re-run the 'tls_generate_keys.sh' script")
            sys.exit(1)

        # Check that there are cert and key files in the directories
        files = os.listdir(dir_paths[f"{key_dir_type}_keys_dir"])
        cert_file_present = any(file.lower().endswith(".crt") for file in files)
        key_file_present = any(file.lower().endswith(".key") for file in files)

        if not cert_file_present or not key_file_present:
            print(f"[ERROR] - The {key_dir_type} keys directory is missing certificate and key files, please re-run the 'tls_generate_keys.sh' script")
            sys.exit(1)

    # Determine which OpenSSL library path should be used
    if os.path.isdir(os.path.join(dir_paths["openssl_path"], "lib64")):
        dir_paths["openssl_lib_dir"] = os.path.join(dir_paths["openssl_path"], "lib64")
    else:
        dir_paths["openssl_lib_dir"] = os.path.join(dir_paths["openssl_path"], "lib")

    # Export the OpenSSL library filepath
    old_ld_library_path = os.environ.get('LD_LIBRARY_PATH', '')
    new_ld_library_path = f"{dir_paths['openssl_lib_dir']}:{old_ld_library_path}"
    os.environ['LD_LIBRARY_PATH'] = new_ld_library_path

    # Define the global openssl_bin path
    openssl_bin = os.path.join(dir_paths["openssl_path"], "bin", "openssl")

    # Define the algorithm-list dictionaries for each PQC, Hybrid-PQC, and classical algorithm category
    alg_lists = {}
    alg_list_paths = {
        "pqc_kem": os.path.join(dir_paths["alg_list_dir"], "tls_kem_algs.txt"),
        "pqc_sig": os.path.join(dir_paths["alg_list_dir"], "tls_sig_algs.txt"),
        "hybrid_kem": os.path.join(dir_paths["alg_list_dir"], "tls_hybr_kem_algs.txt"),
        "hybrid_sig": os.path.join(dir_paths["alg_list_dir"], "tls_hybr_sig_algs.txt"),
        "classic_sig": os.path.join(dir_paths["alg_list_dir"], "tls_classic_sig_algs.txt"),
        "classic_key_exchange": os.path.join(dir_paths["alg_list_dir"], "tls_classic_key_exchange_groups.txt"),
        "classic_ciphersuite": os.path.join(dir_paths["alg_list_dir"], "tls_classic_ciphersuites.txt")
    }

    # Loop through each algorithm category and read in the algorithm lists from the corresponding files
    for alg_cat, list_path in alg_list_paths.items():

        # Initialise the list for the current algorithm category
        alg_lists[alg_cat] = []

        # Open the current alg list file and read in each line
        with open(list_path, "r") as alg_file:
            for line in alg_file:
                alg_lists[alg_cat].append(line.strip())

    # Return the directory paths and algorithm lists
    return dir_paths, alg_lists

#------------------------------------------------------------------------------------------------------------------------------
def get_machine_num():
    """ Helper function for prompting the user to enter a machine-ID for the results directory. The function continues to prompt 
        until a valid positive integer is provided. """

    # Prompt the user to enter a machine-ID until a valid value is given
    while True:

        try:
            
            # Read in the value from the user and strip any whitespace
            machine_id = int(input("What machine-ID would you like to assign to these results? - ").strip())

            # Ensure that the machine-ID is a valid integer and greater than 0
            if machine_id <= 0:
                print("[WARNING] - Invalid machine-ID. Please enter a positive integer.")
                continue

            break

        except ValueError:
            print("[WARNING] - Invalid input. Please enter a valid integer.")

    return machine_id

# ------------------------------------------------------------------------------------------------------------------------------
def handle_results_dir_creation(dir_paths, machine_id):
    """ Function for creating the results directory for the provided machine-ID. If the directory already exists, the user is 
        prompted to either replace the existing results or provide a new machine-ID. The function returns the updated dir_paths 
        dictionary with the results directory path. """

    # Loop until the desired results directory is created successfully
    while True:

        # Define the results directory path based on the machine-ID
        results_path = os.path.join(dir_paths["root_dir"], "test_data", "results", "tls_handshake_bytes", f"machine_{machine_id}")

        # Create the results directory and define it in dir_paths if it does not already exist
        if not os.path.exists(results_path):
            os.makedirs(results_path)
            dir_paths["results_dir"] = results_path
            return dir_paths

        else:

            # Loop until the user provides a valid response to the warning message
            while True:

                # Output the warning message and options to the user
                print(f"\n[WARNING] - The results directory for machine-ID {machine_id} already exists.")
                print(f"\nWould you like to:")
                print("1 - Replace old results and keep the same Machine-ID")
                print("2 - Assign a different Machine-ID\n")

                # Read in the users response and strip any whitespace
                user_choice = input("Please select an option (1-2): ").strip()

                # Determine the user's choice and proceed accordingly
                if user_choice == "1":

                    # Remove the existing results directory and create a new one
                    print("\nReplacing old results...")
                    shutil.rmtree(results_path)
                    os.makedirs(results_path)

                    # Define the results directory in dir_paths and return the updated dict
                    dir_paths["results_dir"] = results_path
                    return dir_paths

                elif user_choice == "2":

                    # Prompt the user to enter a new machine-ID and continue the loop to check if that ID is valid
                    machine_id = get_machine_num()
                    break

                else:
                    print("[WARNING] - Invalid input. Please enter a valid integer (1 or 2).")

#------------------------------------------------------------------------------------------------------------------------------
def configure_result_path(dir_paths):
    """ Function for configuring the results directory path. The directory is set using either a user-defined machine-ID or the 
        default value, and the updated dir_paths dictionary is returned. """

    # Output the current task to the terminal
    print("---------------------------------")
    print("Configuring the Results Directory")
    print(f"---------------------------------\n")

    # Prompt the user to ask if they wish to assign a custom machine-ID to the results directory
    while True:

        # Prompt the user and read in their response
        user_response = input("Would you like to assign a custom machine-ID to the results directory? (y/n): ").strip().lower()

        # Determine the user's choice and proceed accordingly
        if user_response == "y":
            machine_id = get_machine_num()
            break

        elif user_response == "n":
            print("Using default machine-ID of 1 for results directory...")
            machine_id = 1
            break

        else:
            print("[WARNING] - Invalid input. Please enter 'y' for yes or 'n' for no.")

    # Create the results directory based on the machine-ID and update the dir_paths dict accordingly
    dir_paths = handle_results_dir_creation(dir_paths, machine_id)
    return dir_paths

#------------------------------------------------------------------------------------------------------------------------------
def define_openssl_cmds(dir_paths, test_type, cert_key_paths, alg_params, auth_type):
    """ Function for defining the OpenSSL s_server and s_client command lists. Commands are built from the provided test type, 
        signature/KEM pair, and authentication type, then returned for execution with subprocess. """

    # Define the universal provider arguments for the OpenSSL commands
    provider_args = [
        "-provider", "default",
        "-provider", "oqsprovider",
        "-provider-path", os.path.join(dir_paths["oqs_provider_path"], "lib")
    ]

    # Define the base OpenSSL s_server command and arguments
    server_cmd = [
        openssl_bin, "s_server",
        "-cert", cert_key_paths["server_cert"],
        "-key", cert_key_paths["server_key"],
        "-www",
        "-tls1_3",
        "-groups", alg_params[1],
        "-accept", SERVER_ENDPOINT
    ]

    # Define the base OpenSSL s_client command and arguments
    client_cmd = [
        openssl_bin, "s_client",
        "-connect", SERVER_ENDPOINT,
        "-state",
        "-servername", "localhost",
        "-tls1_3",
        "-groups", alg_params[1],
        "-CAfile", cert_key_paths["CA_cert"],
        "-showcerts"
    ]

    # Adjust the base OpenSSL commands based on the test type
    if test_type == "pqc-based":

        # Add the provider arguments to the s_server command for PQC-based tests
        server_cmd += provider_args
        client_cmd += provider_args

    elif test_type == "classic-based":

        # Add the ciphersuite argument to the s_server command for classic-based tests
        server_cmd += ["-ciphersuites", alg_params[2]]
        client_cmd += ["-ciphersuites", alg_params[2]]

    else:
        print(f"[ERROR] - Invalid test type '{test_type}' provided to define_openssl_cmds function.")
        sys.exit(1)
    
    # Add the additional command line arguments needed for mutual authentication
    if auth_type == "mutual_auth":

        # Update the s_server command to require client authentication and provide the CA cert for verification
        server_cmd += ["-Verify", "1", "-verifyCAfile", cert_key_paths["CA_cert"]]

        # Update the s_client command to provide the client cert and key for mutual authentication
        client_cmd += ["-cert", cert_key_paths["client_cert"], "-key", cert_key_paths["client_key"]]

    elif auth_type != "one_way_auth":
        print(f"[ERROR] - Invalid authentication type '{auth_type}' provided to define_openssl_cmds function.")
        sys.exit(1)

    return server_cmd, client_cmd

#------------------------------------------------------------------------------------------------------------------------------
def check_port_availability():
    """ Helper function for checking if the specified port is available for use. If the port is already in use, a RuntimeError 
        is raised. """

    # Open a socket and check if the specified port is available for use
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:

        # Set a timeout for the socket connection attempt to avoid hanging indefinitely
        sock.settimeout(0.25)

        # Check if the port is already in use by attempting to connect to it
        if sock.connect_ex((SERVER_ADDRESS, SERVER_PORT)) == 0:
            raise RuntimeError(f"Port {SERVER_PORT} is already in use, the OpenSSL s_server process cannot be started. Please ensure the port is free and try again.")

#------------------------------------------------------------------------------------------------------------------------------
def process_client_results_output(results_df, client_stdout, test_metadata):
    """ Helper function for processing OpenSSL s_client output. Extracts bytes sent/received during the TLS handshake, updates 
        the provided results dataframe with the extracted values, and returns it. """

    # Define the regex pattern to extract the read and written line from the output
    data_line_pattern = r"SSL handshake has read (\d+) bytes and written (\d+) bytes"

    # Search for the pattern in the client output
    match = re.search(data_line_pattern, client_stdout)

    # If a match is found, extract the read and written bytes
    if match:

        # Extract the read and written bytes from the match groups
        bytes_read = int(match.group(1))
        bytes_written = int(match.group(2))
        total_bytes = bytes_read + bytes_written

    else:

        # If no match is found, raise an error for the caller to report
        raise RuntimeError("Could not find the TLS handshake byte-count line")

    # Determine the test type and then use the params held in the test_metadata dict to define the result row
    new_result_row = []
    if test_metadata["test_type"] == "pqc-based":
        new_result_row = [
            test_metadata["sig_alg"], 
            test_metadata["kem_alg"], 
            test_metadata["auth_type"], 
            bytes_written, 
            bytes_read, 
            total_bytes
        ]

    elif test_metadata["test_type"] == "classic-based":
        new_result_row = [
            test_metadata["sig_alg"],
            test_metadata["key_exchange_group"],
            test_metadata["ciphersuite"],
            test_metadata["auth_type"],
            bytes_written,
            bytes_read,
            total_bytes
        ]

    else:
        raise RuntimeError(f"Unsupported test type supplied to process_client_results_output - {test_metadata['test_type']}")

    # Append the new results row to the results dataframe
    results_df.loc[len(results_df)] = new_result_row

    return results_df

#------------------------------------------------------------------------------------------------------------------------------
def run_openssl_test(server_cmd, client_cmd):
    """ Function for running a single OpenSSL TLS handshake test using the provided s_server and s_client commands. The function
        checks that the server port is available, starts the server, runs the client after the server is ready, validates the
        client output, and ensures that the server process is terminated. The captured client output is returned for 
        processing. """

    # Attempt to run the OpenSSL s_server and s_client commands for the current algorithm/authentication combination
    server_process = None
    try:

        # Ensure that the port is available for use before starting the OpenSSL s_server process
        check_port_availability()

        # Start the OpenSSL s_server process and give it time to initialize before running the s_client command
        server_process = subprocess.Popen(server_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # Wait for the server ACCEPT message to appear in the server's stdout before proceeding with the client connection
        while True:

            # Read in a line from the server process's stdout
            line = server_process.stdout.readline()

            # Check if the server process has outputted the ACCEPT string to the stdout
            if "ACCEPT" in line:
                break

            # Check if the server process has terminated unexpectedly
            if line == "" and server_process.poll() is not None:
                raise RuntimeError(f"Server failed to start:\n{server_process.stderr.read()}")
            
        # Run the OpenSSL s_client command and capture its output
        client_result = subprocess.run(client_cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        client_stdout = client_result.stdout
        client_stderr = client_result.stderr

        # Ensure there were no errors outputted by the client process during the handshake
        if client_result.returncode != 0:
            raise RuntimeError(f"Client error occurred:\n{client_stderr}")

        # Ensure that the client directed data to stdout
        if not client_stdout:
            raise RuntimeError("No output was received from the client process, indicating a potential handshake failure.")

    finally:

        # Terminate the OpenSSL s_server process if it is running
        if server_process is not None:

            # Check if the server process is still running before attempting to terminate it
            if server_process.poll() is None:
                server_process.terminate()

            # Wait for the server process to terminate within 5 seconds, if not force terminate it
            try:
                server_process.wait(timeout=5)
                
            except subprocess.TimeoutExpired:
                server_process.kill()
                server_process.wait()

    # Return the client output for further processing
    return client_stdout

#------------------------------------------------------------------------------------------------------------------------------
def run_tests(dir_paths, alg_lists):
    """ Function for running the TLS handshake byte-count tests for PQC, Hybrid-PQC, and classic algorithm categories. The
        function tests the configured signature, key exchange, ciphersuite, and authentication combinations, processes the
        captured client output, and writes a separate results CSV file for each algorithm category. """

    # Output the current task to the terminal
    print("---------------------------------")
    print("Running TLS Handshake Bytes Tests")
    print(f"---------------------------------")

    # Loop through each type of alg type/category to run bytes test
    for alg_category in ["pqc", "hybrid", "classic"]:

        # Output the current algorithm category being tested to the terminal
        print(f"\nRunning tests for {alg_category.upper()} algorithms:\n")

        # Define the base column headers for results dataframe
        if alg_category == "pqc" or alg_category == "hybrid":
            result_columns = ["Signature Algorithm", "KEM Algorithm", "Authentication Type", "Bytes Sent", "Bytes Received", "Total Bytes"]

        elif alg_category == "classic":
            result_columns = ["Signature Algorithm", "Key Exchange Group", "Ciphersuite", "Authentication Type", "Bytes Sent", "Bytes Received", "Total Bytes"]

        # Define the results algorithm category dataframe
        results_df = pandas.DataFrame(columns=result_columns)

        # Loop through each signature algorithm for the current algorithm category
        for current_sig in alg_lists[f"{alg_category}_sig"]:

            # Define the signature certificate and key files
            cert_key_paths = {
                "CA_cert": os.path.join(dir_paths[f"{alg_category}_keys_dir"], f"{current_sig}_CA.crt"),
                "server_cert": os.path.join(dir_paths[f"{alg_category}_keys_dir"], f"{current_sig}_server.crt"),
                "server_key": os.path.join(dir_paths[f"{alg_category}_keys_dir"], f"{current_sig}_server.key"),
                "client_cert": os.path.join(dir_paths[f"{alg_category}_keys_dir"], f"{current_sig}_client.crt"),
                "client_key": os.path.join(dir_paths[f"{alg_category}_keys_dir"], f"{current_sig}_client.key")
            }

            # Ensure each of these files are present before proceeding
            for file_type, file_path in cert_key_paths.items():
                if not os.path.isfile(file_path):
                    print(f"[ERROR] - The {file_type} file for the {current_sig} signature algorithm is missing, please re-run the 'tls_generate_keys.sh' script")
                    sys.exit(1)

            # Determine which set of testing loops must be performed based on the algorithm category
            if alg_category == "pqc" or alg_category == "hybrid":

                # Loop through each KEM algorithm to test with the signature algorithm
                for current_kem in alg_lists[f"{alg_category}_kem"]:

                    # Perform both one-way and mutual authentication tests for the current KEM/Sig combo
                    for auth_type in ["one_way_auth", "mutual_auth"]:

                        # Set captured client output to default state of none before proceeding
                        captured_client_output = None

                        # Output the current KEM/Sig/Auth combo being tested to the terminal
                        print(f"Testing Signature: {current_sig}, KEM: {current_kem}, Authentication Type: {auth_type}...")

                        # Define the test type based on the algorithm category and type of signature being tested
                        test_type = "pqc-based"

                        # Define the OpenSSL s_server and s_client commands for the current KEM/Sig/Auth combo
                        alg_params = [current_sig, current_kem]
                        server_cmd, client_cmd = define_openssl_cmds(dir_paths, test_type, cert_key_paths, alg_params, auth_type)

                        # Attempt to run the testing and process the results
                        try:

                            # Run the OpenSSL s_server and s_client test, capturing the client output
                            captured_client_output = run_openssl_test(server_cmd, client_cmd)

                            # Process the captured client output to extract the bytes sent/received and update the results dataframe
                            test_metadata = {
                                "test_type": test_type, 
                                "sig_alg": current_sig, 
                                "kem_alg": current_kem, 
                                "auth_type": auth_type
                            }
                            results_df = process_client_results_output(results_df, captured_client_output, test_metadata)

                        except RuntimeError as error:
                            print(f"[ERROR] - During the test for Signature: {current_sig}, "
                                  f"KEM: {current_kem}, "
                                  f"Authentication Type: {auth_type}, "
                                  f"the following error occurred:\n{error}"
                            )
                            sys.exit(1)

            elif alg_category == "classic":

                # Loop through each key exchange group and ciphersuite to test with the signature algorithm
                for current_key_group in alg_lists["classic_key_exchange"]:
                    for current_ciphersuite in alg_lists["classic_ciphersuite"]:

                        # Perform both one-way and mutual authentication tests for the current key exchange/ciphersuite/Sig combo
                        for auth_type in ["one_way_auth", "mutual_auth"]:

                            # Set captured client output to default state of none before proceeding
                            captured_client_output = None

                            # Output the current key exchange/ciphersuite/Sig/Auth combo being tested to the terminal
                            print(f"Testing Signature: {current_sig}, Key Exchange: {current_key_group}, Ciphersuite: {current_ciphersuite}, Authentication Type: {auth_type}...")

                            # Define the test type based on the algorithm category and type of signature being tested
                            test_type = "classic-based"

                            # Define the OpenSSL s_server and s_client commands for the current key exchange/ciphersuite/Sig/Auth combo
                            alg_params = [current_sig, current_key_group, current_ciphersuite]
                            server_cmd, client_cmd = define_openssl_cmds(dir_paths, test_type, cert_key_paths, alg_params, auth_type)

                            # Attempt to run the testing and process the results
                            try:

                                # Run the OpenSSL s_server and s_client test, capturing the client output
                                captured_client_output = run_openssl_test(server_cmd, client_cmd)

                                # Process the captured client output to extract the bytes sent/received and update the results dataframe
                                test_metadata = {
                                    "test_type": test_type, 
                                    "sig_alg": current_sig, 
                                    "key_exchange_group": current_key_group, 
                                    "ciphersuite": current_ciphersuite, 
                                    "auth_type": auth_type
                                }
                                results_df = process_client_results_output(results_df, captured_client_output, test_metadata)

                            except RuntimeError as error:
                                print(
                                    f"[ERROR] - During the test for Signature: {current_sig}, "
                                    f"Key Exchange: {current_key_group}, "
                                    f"Ciphersuite: {current_ciphersuite}, "
                                    f"Authentication Type: {auth_type}, "
                                    f"the following error occurred:\n{error}"
                                )
                                sys.exit(1)

        # Output the current algorithm category results dataframe to a CSV file
        results_csv_path = os.path.join(dir_paths["results_dir"], f"{alg_category}_tls_handshake_bytes_results.csv")
        results_df.to_csv(results_csv_path, index=False)

#------------------------------------------------------------------------------------------------------------------------------
def main():
    """ Main function for executing the TLS handshake byte-count test suite. Sets up the base environment, configures the 
        results directory path, runs tests for each algorithm category, and writes CSV outputs. """

    # Output the welcome message to the terminal
    print("####################################################")
    print("PQC-LEO - TLS Handshake Transmission Cost Test Suite")
    print(f"####################################################\n")

    # Setup the base environment and configure the result path for the test results
    dir_paths, alg_lists = setup_base_env()
    dir_paths = configure_result_path(dir_paths)

    # Run the TLS handshake bytes tests for each algorithm category and output the results to CSV files
    run_tests(dir_paths, alg_lists)

    # Output the completion message to the terminal
    print(f"\nAll tests have completed. Results can be found in the following directory:")
    print(f"{dir_paths['results_dir']}")

#------------------------------------------------------------------------------------------------------------------------------
"""Main boilerplate"""
if __name__ == "__main__":
    main()
