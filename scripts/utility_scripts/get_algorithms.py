"""
Copyright (c) 2023-2025 Callum Turino
SPDX-License-Identifier: MIT

Utility script for retrieving supported cryptographic algorithms from the Liboqs, OpenSSL (classic + PQC), and OQS-Provider libraries. 
It outputs these algorithms to text files used by benchmarking and parsing scripts to determine which 
algorithms to test and evaluate for computational performance and TLS handshakes testing.

Primarily intended to be called by the main setup.sh script, this utility accepts an argument that specifies 
the installation type and determines which algorithm lists should be generated. It can also be executed manually.

Accepted arguments:
    1 - Computational performance testing only (Liboqs algorithms)
    2 - Computational and TLS performance testing (Liboqs, OpenSSL, and OQS-Provider algorithms)
    3 - TLS performance testing only (OpenSSL and OQS-Provider algorithms)
    4 - Parse ALGORITHMS.md in the OQS-Provider source to count the total number of supported algorithms
"""

#------------------------------------------------------------------------------------------------------------------------------
import os
import subprocess
import sys
import re

# Set the root directory path variable
root_dir = ""

# Set the path to the liboqs build directory and the OpenSSL path
liboqs_build_dir = ""
openssl_path = ""
oqs_provider_path = ""
openssl_lib_dir = ""
oqs_provider_src_dir = ""

#------------------------------------------------------------------------------------------------------------------------------
def output_help_message():
    """ Helper function for outputting the help message to the user when the --help flag is present or
        when incorrect arguments are passed. """

    # Output the supported options and their usage to the user
    print("get_algorithms.py [options]")
    print("\nOptions:")
    print("1        Get the algorithms supported by the Liboqs library")
    print("2        Get the algorithms supported by the Liboqs library and the OQS-Provider library")
    print("3        Get the algorithms supported by the OQS-Provider library")
    print("4        Parse the ALGORITHMS.md file of the OQS-Provider library to get the total number of algorithms supported")
    print("--help   Output the help message to the user")

#------------------------------------------------------------------------------------------------------------------------------
def setup_base_env():
    """ Function for setting up the global environment variables for the test suite. This includes determining the root directory 
        by tracing the script's location and configuring paths for libraries, test data, and temporary files. """

    global root_dir, liboqs_build_dir, openssl_path, openssl_lib_dir, oqs_provider_path, oqs_provider_src_dir

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
            print("Root directory path file not present, please ensure the path is correct and try again.")
            sys.exit(1)

    # Declare the global library directory path variables
    liboqs_build_dir = os.path.join(root_dir, "lib", "liboqs", "build", "tests")
    openssl_path = os.path.join(root_dir, "lib", "openssl_3.5.0")
    oqs_provider_path = os.path.join(root_dir, "lib", "oqs_provider")
    openssl_lib_dir = ""

    # Check the OpenSSL library directory path
    if os.path.isdir(os.path.join(openssl_path, "lib64")):
        openssl_lib_dir = os.path.join(openssl_path, "lib64")

    else:
        openssl_lib_dir= os.path.join(openssl_path, "lib")

    # Export the OpenSSL library filepath
    old_ld_library_path = os.environ.get('LD_LIBRARY_PATH', '')
    new_ld_library_path = f"{openssl_lib_dir}:{old_ld_library_path}"
    os.environ['LD_LIBRARY_PATH'] = new_ld_library_path

    # Set the path to the ALGORITHMS.md file
    oqs_provider_src_dir = os.path.join(root_dir, "tmp", "oqs_provider_source")

    # Ensure that there are no previous list files present (mainly for if this script is run manually, setup.sh will handle this)
    alg_list_dir = os.path.join(root_dir, "test_data", "alg_lists")

    if os.path.isdir(alg_list_dir):
        for file in os.listdir(alg_list_dir):
            os.remove(os.path.join(alg_list_dir, file))
    else:
        os.mkdir(alg_list_dir)

#------------------------------------------------------------------------------------------------------------------------------
def write_to_file(alg_list, file_name):
    """ Helper function to write the algorithms to a specified text file. The function 
        takes the algorithm list and the filename as arguments. """

    # Write the algorithms to the specified text file
    with open(file_name, "w") as f:
        for alg in alg_list:
            f.write(f"{alg}\n")

#------------------------------------------------------------------------------------------------------------------------------
def liboqs_extract_algs(output_str):
    """ Helper function to extract the algorithms from the output string of the liboqs test binaries. 
        The function parses the output string to identify and extract algorithm names. """

    # Initialise the extracted algorithms variable
    extracted_algs = None

    # Split the output string into individual lines for processing
    lines = output_str.splitlines()

    # Iterate through each line to search for algorithm names
    for line in lines:

        # Check if the line contains the "algname:" keyword, which indicates algorithm names
        if "algname:" in line:

            # Split the line at the first occurrence of "algname:" to isolate the algorithm names
            line_split = line.split("algname:", 1)

            # Ensure the split result contains at least two parts (valid format)
            if len(line_split) < 2:
                continue

            # Extract the algorithm names, strip any whitespace, and split by commas
            alg_list_str = line_split[1].strip()
            extracted_algs = [alg.strip() for alg in alg_list_str.split(",") if alg.strip()]

    # Verify that algorithms were successfully extracted; otherwise, output an error message
    if extracted_algs is None:
        print("[ERROR] - No algorithms found in the output string.")
        sys.exit(1)

    return extracted_algs

#------------------------------------------------------------------------------------------------------------------------------
def get_liboqs_algs():
    """ Function to get the algorithms supported by the Liboqs library. The function will run the test
        binaries with no arguments to trigger the help output, which will contain the algorithms supported. """
    
    # Set the test_bins and output directory for algorithm lists
    test_bins = [f"{liboqs_build_dir}/test_kem", f"{liboqs_build_dir}/test_sig"]
    output_dir = os.path.join(root_dir, "test_data", "alg_lists")

    # Loop through the different test type binaries (KEM and SIG) and run them
    for bin in test_bins:

        # Check if the test binary exists before running
        if os.path.isfile(bin):

            # Attempt to run the test binary and capture the output
            try:

                # Run the relevant test binary and capture the output
                process = subprocess.Popen(bin, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
                stdout, stderr = process.communicate()

                # Extract the algorithms from the stderr
                algs = liboqs_extract_algs(stderr)

                # Set the output filename for the current algorithm type
                if "kem" in bin:
                    alg_list_file = os.path.join(output_dir, "kem_algs.txt")
                else:
                    alg_list_file = os.path.join(output_dir, "sig_algs.txt")

                # Filter out HQC KEM algorithms from the list if the HQC enabled flag is not set (temp fix for HQC bug)
                if not os.path.exists(os.path.join(root_dir, "tmp", ".hqc_enabled.flag")):
                    algs = [alg for alg in algs if not alg.startswith("HQC")]
                
                # Write out the algorithms to the list file
                write_to_file(algs, alg_list_file)

            except Exception as e:
                print(f"[ERROR] - {e}")
            
        else:
            print(f"[ERROR] - Test binary '{bin}' not found.")
            return

#------------------------------------------------------------------------------------------------------------------------------
def extract_tls_algs(test_type, provider_type, output_str):
    """ Helper function for extracting PQC and Hybrid-PQC algorithms supported by OpenSSL and OQS-Provider from the output string, 
        filtering based on the test type (PQC or Hybrid-PQC) and the provider type (OpenSSL or OQS-Provider). """

    # Set the algorithm lists used for the PQC and Hybrid-PQC algorithms
    algs = []
    hybrid_algs = []

    # Set the filter and match variables used in the test types checks
    hybrid_prefix_pattern = re.compile(r'^(rsa[0-9]+|p[0-9]+|x[0-9]+|X25519|X448|SecP256r1|SecP384r1|SecP521r1)[a-zA-Z0-9_-]+$')
    excluded_algs = ["CROSSrsdp256small", "X448MLKEM1024"]
    # Leave commented until SLH-DSA is supported for TLS handshakes in OpenSSL
    #native_pqc_pattern = re.compile(r'^(MLKEM[0-9]+|MLDSA[0-9]+|SLH-DSA-[A-Z0-9-]+[a-z]*)$')

    # Set the UOV and SNOVA exclude and include patterns
    exclude_pattern = re.compile(r'^(p(256|384|521)_)?(OV_|snova)')
    include_list = [
        "OV_Ip_pkc", "p256_OV_Ip_pkc",
        "OV_Ip_pkc_skc", "p256_OV_Ip_pkc_skc",
        "snova2454", "p256_snova2454",
        "snova2454esk", "p256_snova2454esk",
        "snova37172", "p256_snova37172",
        "snova2455", "p384_snova2455",
        "snova2965", "p521_snova2965"
    ]

    # Set the regex pattern to match OpenSSL native PQC algorithms depending on the test type
    if test_type == 0:
        native_pqc_pattern = re.compile(r'^(MLKEM[0-9]+|MLDSA[0-9]+)$')
    else:
        native_pqc_pattern = re.compile(r'^(MLKEM[0-9]+)$')

    # Pre-format the output string to remove newlines and split into a list
    pre_algs = output_str.split("\n")
    pre_algs = pre_algs[:-1]

    # Loop through the pre-formatted algorithms and add to the appropriate list
    for alg in pre_algs:

        # Clean up the algorithm string before checks
        alg = alg.strip()

        # If braces present, get last alias (usually best readable name)
        if alg.startswith("{"):

            brace_content = alg.split("}")[0]  # get the content before closing brace
            items = brace_content.strip("{ ").split(",")
            alg = items[-1].strip()

        else:
            # If no braces, get the last part of the string
            alg = alg.strip()
            alg = alg.split(" @ ")[0]

        # Skip over algorithms that are to be excluded from the list
        if test_type == 0 and ((exclude_pattern.match(alg) and alg not in include_list) or alg in excluded_algs):
            continue

        # Determine what filters are needed based on the provider type
        if provider_type == "default":

            # Determine if the algorithm is a PQC or a Hybrid-PQC algorithm
            if native_pqc_pattern.match(alg):

                # If the algorithm is ML-KEM and the test type is speed, reformat the algorithm name
                if test_type == 1:
                    if "MLKEM" in alg:
                        alg = re.sub(r'^MLKEM(\d+)$', r'ML-KEM-\1', alg)

                # Add the algorithm to the algorithms list
                algs.append(alg.strip())

            elif hybrid_prefix_pattern.match(alg):

                # Add the algorithm to the hybrid algorithms list
                hybrid_algs.append(alg.strip())

        elif provider_type == "oqsprovider":

            # Determine if the algorithm is a PQC or a Hybrid-PQC algorithm
            if hybrid_prefix_pattern.match(alg):
                hybrid_algs.append(alg.strip())
            else:
                algs.append(alg.strip())

        else:
            print(f"[ERROR] - Unknown provider type '{provider_type}'")
            sys.exit(1)

    return algs, hybrid_algs

#------------------------------------------------------------------------------------------------------------------------------
def get_tls_pqc_algs():
    """ Retrieves the PQC and Hybrid-PQC algorithms supported by both OpenSSL and OQS-Provider for TLS benchmarking. """

    # Set required path variables, algorithm categories, and provider flags
    openssl_bin = os.path.join(openssl_path, "bin", "openssl")
    output_dir = os.path.join(root_dir, "test_data", "alg_lists")
    alg_cats = ["kem", "signature"]
    provider_flags = {
        "default": ["-provider", "default"], 
        "oqsprovider": ["-provider", "oqsprovider", "-provider-path", oqs_provider_path]
    }

    # Loop through the different algorithm types and get the algorithms supported
    for alg_type in alg_cats:

        # Set the master algorithms lists for the current algorithm type
        algs = []
        hybrid_algs = []
        speed_algs = []
        speed_hybrid_algs = []

        # Loop through each of the provider types that algorithms need to be extracted from
        for provider_type in provider_flags.keys():

            # Run the openssl binary with the required flags to get the algorithms supported and capture the output
            process = subprocess.Popen(
                [openssl_bin, "list", f"-{alg_type}-algorithms"] + provider_flags[provider_type],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True
            )
            stdout, stderr = process.communicate()

            # Extract the PQC and Hybrid-PQC algorithms for TLS handshakes from the output string
            test_type = 0
            provider_algs, provider_hybrid_algs = extract_tls_algs(test_type, provider_type, stdout)

            # Append the extracted algorithms to the master lists
            algs.extend(provider_algs)
            hybrid_algs.extend(provider_hybrid_algs)

            # Extract the speed algorithms for the current algorithm type
            test_type = 1
            provider_algs, provider_hybrid_algs = extract_tls_algs(test_type, provider_type, stdout)

            # Append the extracted algorithms to the master lists
            speed_algs.extend(provider_algs)
            speed_hybrid_algs.extend(provider_hybrid_algs)

        # Set the various output filenames depending on the current algorithm type
        alg_list_file = os.path.join(output_dir, f"tls_{alg_type[:3]}_algs.txt")
        hybrid_alg_list_file = os.path.join(output_dir, f"tls_hybr_{alg_type[:3]}_algs.txt")
        speed_list_file = os.path.join(output_dir, f"tls_speed_{alg_type[:3]}_algs.txt")
        speed_hybrid_alg_list_file = os.path.join(output_dir, f"tls_speed_hybr_{alg_type[:3]}_algs.txt")

        # Write out the algorithms to the list files
        write_to_file(algs, alg_list_file)
        write_to_file(hybrid_algs, hybrid_alg_list_file)
        write_to_file(speed_algs, speed_list_file)
        write_to_file(speed_hybrid_algs, speed_hybrid_alg_list_file)

#------------------------------------------------------------------------------------------------------------------------------
def set_tls_classic_algs():
    """ Function to set the classic algorithm lists for the TLS benchmarking. The classic algorithms are not subject 
        to change, so they can be set in the script and then outputted to text files for the benchmarking and parsing scripts. """

    # Set the classic algorithms for the TLS benchmarking
    classic_kems = ["prime256v1", "secp384r1", "secp521r1"]
    classic_sigs = ["RSA_2048", "RSA_3072", "RSA_4096", "prime256v1", "secp384r1", "secp521r1"]

    # Set the output directory and text file names
    output_dir = os.path.join(root_dir, "test_data", "alg_lists")
    kem_list_file = os.path.join(output_dir, "classic_tls_kem_algs.txt")
    sig_list_file = os.path.join(output_dir, "classic_tls_sig_algs.txt")
    
    # Write out the classic algorithms to the list files
    write_to_file(classic_kems, kem_list_file)
    write_to_file(classic_sigs, sig_list_file)

#------------------------------------------------------------------------------------------------------------------------------
def parse_oqs_provider_algorithms_md():
    """ Function for parsing the ALGORITHMS.md file of the OQS-Provider library to extract the total number of algorithms supported
        This is only called when all algorithms are selected to be enabled by the main setup.sh script, as the OpenSSL speed.c source
        file needs to be altered so that a larger number of algorithms can be supported. This function will return the total number of algorithms
        supported by the OQS-Provider library, and if parsing fails returns -1 to indicate that the hardcoded high value should be set in the speed.c file. """

    # Set the filepaths for the ALGORITHMS.md file and declare the main_algs list
    algs_md_filepath = os.path.join(oqs_provider_src_dir, "ALGORITHMS.md")
    main_algs = []

    # Set the in_table to its default value
    in_table = False

    # Try to open the ALGORITHMS.md file and extract the algorithms from the table
    try:

        # Ensure that the file is present
        if not os.path.isfile(algs_md_filepath):
            raise FileNotFoundError()
                
        # Open the ALGORITHMS.md file and extract the number of algorithms supported
        with open (algs_md_filepath, "r", encoding='utf-8') as file:
            for line in file:

                # Determine if the script is currently in the table of algorithms
                if "<!--- OQS_TEMPLATE_FRAGMENT_IDS_START -->" in line:
                    in_table = True
                    continue
                
                elif "<!--- OQS_TEMPLATE_FRAGMENT_IDS_END -->" in line:
                    break
                
                # If in the table, extract the algorithm names
                if in_table:

                    # Only extract the algorithms if not in the first lines of the table
                    if "Algorithm" in line or "--" in line:
                        continue

                    else:

                        # Extract the algorithm name from the row and store it in the main_algs list
                        row = line.split("|")
                        del row[0]
                        main_algs.append(row[0].strip())

        # Check that the table was found and the algorithm names were extracted
        if not main_algs:
            raise Exception("No algorithms found in the table")

    except FileNotFoundError:
        print(f"File not found: {algs_md_filepath}")
        sys.exit(1)

    except Exception as e:
        print(f"Failed to parse processing file structure: {e}")
        sys.exit(1)

    # Print out the number of algorithms supported by the OQS-Provider library and exit successfully
    print(f"Total number of Algorithms: {len(main_algs)}")
    sys.exit(0)
    
#------------------------------------------------------------------------------------------------------------------------------
def main():
    """ Main function for controlling the utility script. The function will determine which algorithms 
        are required based on the argument passed to the script. """
    
    # Check if the help flag was passed before continuing
    if "--help" in sys.argv:
        output_help_message()
        sys.exit(0)

    # Ensure a valid argument was passed to the utility script
    if len(sys.argv) == 2:

        # Set up the base environment for the utility script
        setup_base_env()

        # Determine which algorithm lists are required based on the argument passed, and create them
        if sys.argv[1] == "1":

            # Ensure that the Liboqs library is present before continuing
            if not os.path.isdir(liboqs_build_dir):
                print("[ERROR]- Liboqs library not found")
                sys.exit(1)
            
            # Get the algorithms supported by the Liboqs library
            get_liboqs_algs()

        elif sys.argv[1] == "2":

            #Ensure that the Liboqs, OpenSSL, and OQS-Provider libraries are present before continuing
            if not os.path.isdir(liboqs_build_dir):
                print("[ERROR]- Liboqs library not found")
                sys.exit(1)

            elif not os.path.isdir(oqs_provider_path):
                print("[ERROR]- OQS-Provider library not found")
                sys.exit(1)

            elif not os.path.isdir(openssl_path):
                print("[ERROR]- OpenSSL library not found")
                sys.exit(1)

            # Get the algorithms supported by the Liboqs library
            get_liboqs_algs()

            # Get the algorithms supported by the OQS-Provider library and set the classic TLS algorithms
            get_tls_pqc_algs()
            set_tls_classic_algs()

        elif sys.argv[1] == "3":

            # Ensure that the OQS-Provider and OpenSSL libraries are present before continuing
            if not os.path.isdir(oqs_provider_path):
                print("[ERROR]- OQS-Provider library not found")
                sys.exit(1)

            elif not os.path.isdir(openssl_path):
                print("[ERROR]- OpenSSL library not found")
                sys.exit(1)
            
            # Get the algorithms supported by the OQS-Provider library and set the classic TLS algorithms
            get_tls_pqc_algs()
            set_tls_classic_algs()

        elif sys.argv[1] == "4":

            # Ensure that the OQS-Provider source directory is present before continuing
            if not os.path.isdir(oqs_provider_src_dir):
                print("[ERROR]- OQS-Provider source directory not found")
                sys.exit(1)

            # Parse the ALGORITHMS.md file in the OQS-Provider source directory to get the total number of algorithms supported
            parse_oqs_provider_algorithms_md()

        else:

            # Output an error message if an invalid argument was passed
            print(f"\nInvalid argument has been passed to this utility script, please check the code of the setup.sh script, or if you are running this script manually, ensure you are passing the correct argument")
            print("Required arguments are: 1 (Liboqs only), 2 (liboqs and OQS-Provider), or 3(OQS-Provider only)")
            print(f"\nArgument passed - ", sys.argv[1])
            sys.exit(1)
    
    else:

        # Output an error message if an invalid number of arguments were passed
        print("Invalid number of arguments passed to the utility script, please check the code of the setup.sh script, or if you are running this script manually, ensure you are passing the correct number of arguments")
        sys.exit(1)

#------------------------------------------------------------------------------------------------------------------------------
"""Main boiler plate"""
if __name__ == "__main__":
    main()