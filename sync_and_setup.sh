#!/usr/bin/env bash

# Set strict error handling
set -euo pipefail

# Environment variables and constants
PLATFORM=$(uname)

ETL_DIR="$HOME/Documents/etl"
GIT_REPO_URL="https://github.com/ad-net/etl.git" 

# If first time, on jump drive, run: ssh-keygen -t rsa -b 4096
# ssh-copy-id  {user}@jump.ad.net on every server
KEY_DIR="$HOME/key"
STAGING_DIR="$HOME/staging"
REMOTE_KEY_DIR="chris.pachulski@jump.ad.net:/home/chris.pachulski/key/" 
REMOTE_STAGING_DIR="chris.pachulski@jump.ad.net:/home/chris.pachulski/staging/" 

DOCKER_IMAGE="airflow.ad.net:5000/ad.net/report-script-file:latest"
REQUIREMENTS_DIR="$HOME/Documents/python_folder"
ENV_NAME="current_staging_environ"

# Install required packages
install_package() {
    local package_name=$1
    echo "Checking for $package_name..."
    if ! command -v "$package_name" &>/dev/null; then
        echo "Installing $package_name..."
        case "$PLATFORM" in
        Darwin)
            brew list "$package_name" &>/dev/null || brew install "$package_name"
            ;;
        Linux)
            if [[ -f "/etc/debian_version" ]]; then # Debian-based distributions
                dpkg -l "$package_name" &>/dev/null || { sudo apt-get update && sudo apt-get install -y "$package_name"; }
            elif [[ -f "/etc/redhat-release" ]]; then # Red Hat-based distributions
                rpm -q "$package_name" &>/dev/null || sudo yum install -y "$package_name"
            else
                echo "Unsupported Linux distribution for automatic installation."
                return 1
            fi
            ;;
        *)
            echo "Unsupported platform for $package_name installation."
            return 1
            ;;
        esac
    else
        echo "$package_name is already installed."
    fi
}

# Function to install Docker
install_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Installing Docker..."
        case "$PLATFORM" in
        Darwin)
            brew install --cask docker
            ;;
        Linux)
            curl -fsSL https://get.docker.com | sh
            ;;
        *)
            echo "Docker installation is not supported on this platform."
            return 1
            ;;
        esac
    else
        echo "Docker is already installed."
    fi

    echo "After installing Docker, apply the following Docker Engine configuration:"
            echo '{
                  "builder": {
                    "gc": {
                      "defaultKeepStorage": "20GB",
                      "enabled": true
                    }
                  },
                  "experimental": false,
                  "features": {
                    "buildkit": true
                  },
                  "insecure-registries": [
                    "https://airflow.ad.net:5000"
                  ]
                }'
}

# Ensure required software is installed
ensure_software_installed() {
    echo "Ensuring required software is installed..."
    if [[ "$PLATFORM" == 'Darwin' ]]; then
        # Install Homebrew if not installed
        which brew > /dev/null || {
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        }
        install_docker
        [ -d "/Applications/Docker.app" ] && open /Applications/Docker.app
        install_package "git"
        install_package "rsync"
        install_package "vim"
        # For macOS, using brew services to manage PostgreSQL
        install_package "postgresql"
        if ! brew services list | grep -q "^postgresql.*started"; then
            echo "Starting PostgreSQL..."
            brew services start postgresql
        else
            echo "PostgreSQL is already running."
        fi
    elif [[ "$PLATFORM" == 'Linux' ]]; then
        install_docker
        # Assuming Docker and Git are available through the package manager
        install_package "git"
        install_package "rsync"
        # Assuming PostgreSQL installation also creates its service
        install_package "postgresql"
        if ! systemctl is-active --quiet postgresql; then
            echo "Starting PostgreSQL..."
            sudo systemctl enable --now postgresql
        else
            echo "PostgreSQL service is already active."
        fi
    else
        echo "Unsupported platform for service management."
    fi
}

# Install Anaconda
install_anaconda() {
    if ! command -v conda &>/dev/null; then
        echo "Installing Anaconda..."
        local anaconda_script="Miniconda3-latest-$(echo "$PLATFORM" | awk '{print tolower($0)}')-x86_64.sh"
        curl -O "https://repo.anaconda.com/miniconda/$anaconda_script"
        bash "$anaconda_script" -b -p "$HOME/miniconda"
        eval "$($HOME/miniconda/bin/conda shell.bash hook)"
        conda init
    fi
    conda list python | grep "^python\s*3\." || conda install python=3 -y
}

set_git_to_ssh() {
    echo "Setting Git remote URL to use SSH..."
    git -C "$ETL_DIR" remote set-url origin git@github.com:ad-net/etl.git
    echo "Git remote URL has been updated to use SSH."
}

# Function to instruct the user on generating SSH key and adding it to GitHub
generate_ssh_instructions() {
    echo "If you encounter an error or if Git prompts for a username, you may need to set up SSH keys."
    echo "To generate a new SSH key, run: ssh-keygen -t ed25519 -C \"your_email@example.com\""
    echo "Ensure you replace \"your_email@example.com\" with your actual email address."
    echo "To start the ssh-agent run: eval \"$(ssh-agent -s)\""
    echo "Add your private key to the ssh-agent by running: ssh-add ~/.ssh/id_ed25519"
    echo "Copy the key to your clipboard by running: pbcopy < ~/.ssh/id_ed25519.pub (macOS) or xclip -sel clip < ~/.ssh/id_ed25519.pub (Linux)"
    echo "Navigate to your GitHub account. Under settings, select SSH and GPG Keys"
    echo "Select New SSH Key, and paste in your key under the 'key' box, and provide a title."
    echo "Click Add SSH key. Restart your terminal, and bash this script again."
}

# Clone or update the ETL repository
update_etl_repository() {
    if [ ! -d "$ETL_DIR/.git" ]; then
        echo "ETL directory does not exist. Cloning from Git repository..."
        if ! git clone "$GIT_REPO_URL" "$ETL_DIR"; then
            generate_ssh_instructions
            set_git_to_ssh
            exit 1
        fi
    else
        echo "ETL directory exists. Updating from Git repository..."
        cd "$ETL_DIR" || exit
        if ! git fetch origin; then
            generate_ssh_instructions
            set_git_to_ssh
            # Attempt fetch again after setting to SSH
            if ! git fetch origin; then
                echo "Failed to fetch updates from Git repository even after setting to SSH."
                exit 1
            fi
        fi
        git reset --hard origin/master
    fi
}

localize_repo_pathing(){
	DIRECTORY="$HOME/Documents/etl/external-reporting/docker-images/report-script-file/scripts/"
	SEARCH_TEXT_1="/key"
	SEARCH_TEXT_2="/root/.config/gspread_pandas"
	SEARCH_TEXT_3="/tmp/"
	REPLACEMENT_TEXT_1="$HOME/key"
	REPLACEMENT_TEXT_2="$HOME/Downloads/"

	export DIRECTORY
	export SEARCH_TEXT_1
	export SEARCH_TEXT_2
	export SEARCH_TEXT_3
	export REPLACEMENT_TEXT_1
	export REPLACEMENT_TEXT_2

	update_key_directories=$(cat <<EOF
import os

def replace_text_in_file(file_path, search_text, replacement_text):
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
        file_contents = file.read()
    
    file_contents = file_contents.replace(search_text, replacement_text)
    
    with open(file_path, 'w', encoding='utf-8', errors='ignore') as file:
        file.write(file_contents)


def main(directory, search_text, replacement_text):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.py') or file.endswith('.sh'):
                file_path = os.path.join(root, file)
                replace_text_in_file(file_path, search_text, replacement_text)


directory = os.environ['DIRECTORY']
search_text_1 = os.environ['SEARCH_TEXT_1']
replacement_text_1 = os.environ['REPLACEMENT_TEXT_1']
main(directory, search_text_1, replacement_text_1)

search_text_2 = os.environ['SEARCH_TEXT_2']
replacement_text_1 = os.environ['REPLACEMENT_TEXT_1']
main(directory, search_text_2, replacement_text_1)
print('Production /key directory has been replaced with local pathing in all applicable scripts.')

search_text_3 = os.environ['SEARCH_TEXT_3']
replacement_text_2 = os.environ['REPLACEMENT_TEXT_2']
main(directory, search_text_3, replacement_text_2)
print('Production /tmp/ directory has been replaced with local Download pathing in all applicable scripts.')
EOF
)

	python3 -c "$update_key_directories"
}

process_script_files() {
    local script_dir=$1
    local dest_dir=$2
    local script_type=$3 # "python" or "r"

    for script_file in "$script_dir"/*.sh; do
        base_name=$(basename "$script_file" .sh)
        # Check for 'python3 -c' command and script type is python
        if grep -q 'python3 -c' "$script_file" && [ "$script_type" = "python" ]; then
            # Extract and process Python script content
            if grep -q 'EOF' "$script_file"; then
                # Heredoc style, avoiding complex regex that might cause compatibility issues
                awk '/=\s*\$\(cat <<EOF/,/^EOF/' "$script_file" | 
                sed '1d;$d' | # Remove the first and last line of the output
                sed 's/\\"/"/g' > "$dest_dir/${base_name}.py"
            else
                # Non-heredoc style
                sed -n '/^.*[Ss]cript="/,/^"/p' "$script_file" | 
                sed '1d;$d' | # Remove the first and last line of the output
                sed 's/\\"/"/g' > "$dest_dir/${base_name}.py" # Replace \" with "
            fi
        # Check for 'Rscript -' command and script type is r
        elif grep -q 'Rscript -' "$script_file" && [ "$script_type" = "r" ]; then
            # Extract and process R script content
            if grep -q 'EOF' "$script_file"; then
                # Heredoc style, using awk for simplicity
                awk '/=\s*\$\(cat <<EOF/,/^EOF/' "$script_file" | 
                sed '1d;$d' | # Remove the first and last line of the output
                sed 's/\\"/"/g' | # Replace \" with "
                sed 's/\\\$/$/g' > "$dest_dir/${base_name}.R" # Replace \$ with $
            else
                # Non-heredoc style
                sed -n '/^.*[Ss]cript="/,/^"/p' "$script_file" | 
                sed '1d;$d' | # Remove the first and last line of the output
                sed 's/\\"/"/g' | # Replace \" with "
                sed 's/\\\$/$/g' > "$dest_dir/${base_name}.R" # Replace \$ with $
            fi
        fi
    done
}

extract_repo_scripts_from_shells(){
    # Setup directories
    PYTHON_SCRIPTS_DIR="$HOME/Documents/etl/external-reporting/docker-images/report-script-file/scripts"
    PYTHON_DEST_DIR="$HOME/Documents/python_folder/production_python_scripts"
    R_DEST_DIR="$HOME/Documents/r_folder/production_r_scripts"

    # Cleanup and recreate destination directories
    rm -rf "$PYTHON_DEST_DIR" "$R_DEST_DIR"
    mkdir -p "$PYTHON_DEST_DIR" "$R_DEST_DIR"

    # Assuming process_script_files is defined elsewhere and processes files from source to destination based on language
    process_script_files "$PYTHON_SCRIPTS_DIR" "$PYTHON_DEST_DIR" "python"
    process_script_files "$PYTHON_SCRIPTS_DIR" "$R_DEST_DIR" "r"

    # Define source and destination directories for Python functions
    PYTHON_FUNCTIONS_DIR="$HOME/Documents/etl/external-reporting/docker-images/report-script-file/scripts/addotnet_functions/"
    PYTHON_FUNCTIONS_DEST_DIR_0="$HOME/Documents/python_folder/production_python_scripts/addotnet_functions"
    PYTHON_FUNCTIONS_DEST_DIR_1="$HOME/Documents/python_folder/addotnet_functions"
    PYTHON_FUNCTIONS_DEST_DIR_2="$HOME/Documents/r_folder/addotnet_functions"
    PYTHON_FUNCTIONS_DEST_DIR_3="$HOME/Documents/r_folder/production_r_scripts/addotnet_functions"

    # Ensure the destination directories exist (create them if they don't)
    mkdir -p "$PYTHON_FUNCTIONS_DEST_DIR_0" "$PYTHON_FUNCTIONS_DEST_DIR_1" "$PYTHON_FUNCTIONS_DEST_DIR_2" "$PYTHON_FUNCTIONS_DEST_DIR_3"

    # Copy the directory and its contents to the destinations
    cp -R "$PYTHON_FUNCTIONS_DIR"/* "$PYTHON_FUNCTIONS_DEST_DIR_0"
    cp -R "$PYTHON_FUNCTIONS_DIR"/* "$PYTHON_FUNCTIONS_DEST_DIR_1"
    cp -R "$PYTHON_FUNCTIONS_DIR"/* "$PYTHON_FUNCTIONS_DEST_DIR_2"
    cp -R "$PYTHON_FUNCTIONS_DIR"/* "$PYTHON_FUNCTIONS_DEST_DIR_3"

    echo "Python/R Script extraction processing complete."
}


retrieve_keys_from_jumpdrive(){
	mkdir -p "$KEY_DIR" "$STAGING_DIR"

    if ! rsync -avzhe ssh "$REMOTE_KEY_DIR" "$KEY_DIR/"; then
	    # rsync failed, print the error message and instructions
	    echo "Failed to synchronize keys with rsync. Please set up and bash the following script on your jump drive:"
	    echo '#!/bin/bash

			# Path to the directory you want to copy
			SOURCE_DIR="root@airflow3.data:/usr/local/airflow/external-reporting-key"

			# Destination path on the server
			DESTINATION="/home/{your.name}/key"

			# Using scp to transfer the folder. Note the use of -r for recursive copy.
			scp -r $SOURCE_DIR $DESTINATION
			'
	    echo "This will require you generate ssh keys via:
			ssh-keygen -t rsa -b 2048
			if you haven't already. Then:
			ssh-copy-id {your.name}@jump.ad.net
			and provide password"
	    exit 1
	fi

	if ! rsync -avzhe ssh "$REMOTE_STAGING_DIR" "$STAGING_DIR/"; then
	    # rsync failed, print the error message and instructions
	    echo "Failed to synchronize staging with rsync. Please set up and bash the following script on your jump drive:"
	    echo '#!/bin/bash

				# Path to the directory you want to copy
				SECOND_SOURCE_DIR="root@airflow3.data:/root/bi_production_environment"

				# Destination path on the server
				SECOND_DESTINATION="/home/chris.pachulski/staging"

				# Using scp to transfer the folder. Note the use of -r for recursive copy.
				scp -r $SECOND_SOURCE_DIR $SECOND_DESTINATION
				'
	    echo "This will require you generate ssh keys via:
			ssh-keygen -t rsa -b 2048
			if you haven't already. Then:
			ssh-copy-id {your.name}@jump.ad.net
			and provide password"
	    exit 1
	fi

    #Position google_secret for googlesheet interaction locally
    GSPREAD_PANDAS_DIR="$HOME/.config/gspread_pandas"
	mkdir -p "$GSPREAD_PANDAS_DIR"
	cp "$HOME/key/google_secret.json" "$GSPREAD_PANDAS_DIR"
}

# Prepare Docker environment
prepare_docker_environment() {
    echo "Checking for Docker image updates..."
    PULL_OUTPUT=$(docker pull "$DOCKER_IMAGE" 2>&1)
    if [[ "$PULL_OUTPUT" == *"Status: Image is up to date for"* ]]; then
        echo "Docker image is up to date."
    elif [[ "$PULL_OUTPUT" == *"Downloaded newer image for"* ]] || [[ "$PULL_OUTPUT" == *"Status: Downloaded newer image for"* ]]; then
        echo "Docker image updated. New image pulled."
    else
        echo "Docker image not found locally. Pulling from registry..."
        docker pull "$DOCKER_IMAGE"
    fi
}

# Setup Anaconda Activation Script with Environmental Variables
acquire_install_environmental_variables(){
	SCRIPT_PATH="$STAGING_DIR/report-scripts.sh"

	# Create the directory for the Conda environment activation scripts if it doesn't exist
	mkdir -p "$HOME/anaconda3/envs/$ENV_NAME/etc/conda/activate.d"
	mkdir -p "$HOME/anaconda3/envs/$ENV_NAME/etc/conda/deactivate.d"

	# Activation script path
	ACTIVATION_SCRIPT="$HOME/anaconda3/envs/$ENV_NAME/etc/conda/activate.d/env_vars.sh"
	DEACTIVATION_SCRIPT="$HOME/anaconda3/envs/$ENV_NAME/etc/conda/deactivate.d/env_vars.sh"
	rm -rf $ACTIVATION_SCRIPT
	rm -rf $DEACTIVATION_SCRIPT

	# Initialize the activation and deactivation scripts
	echo "#!/bin/sh" > "$ACTIVATION_SCRIPT"
	echo "#!/bin/sh" > "$DEACTIVATION_SCRIPT"

	chmod +x $SCRIPT_PATH
	# Extract -e lines and format them for the Conda activation script
	grep "^  -e" "$SCRIPT_PATH" | while IFS= read -r line; do
	    # Remove the leading '-e ' from each line and trailing backslashes
	    var_assignment=$(echo "$line" | sed 's/^  -e //;s/ \\$//')

	    # Echo the variable assignment for debugging or verification
	    echo "Adding to activation script: $var_assignment"

	    # Write the full export command to the activation script
	    echo "export $var_assignment" >> "$ACTIVATION_SCRIPT"

	    # Extract just the variable name for the deactivation script
	    var_name=$(echo "$var_assignment" | cut -d '=' -f 1)

	    # Write the unset command to the deactivation script
	    echo "unset $var_name" >> "$DEACTIVATION_SCRIPT"
	done


	# After processing all -e lines from the script
	if [[ $(uname) == "Darwin" ]]; then
	    # Use awk to replace the line containing PROCESS_DATE for macOS
	    awk -v var="export PROCESS_DATE=\$(date -v-1d +\"%Y-%m-%d\")" \
	    '{ if ($0 ~ /^export PROCESS_DATE=/) print var; else print $0; }' "$ACTIVATION_SCRIPT" > temp_file && mv temp_file "$ACTIVATION_SCRIPT"
	fi


	# After adding variables, cat the activation script for review
	echo "Activation script contents:"
	cat "$ACTIVATION_SCRIPT"


	# Make the activation and deactivation scripts executable
	chmod +x "$ACTIVATION_SCRIPT"
	chmod +x "$DEACTIVATION_SCRIPT"

	echo "Environment variables have been added to the Conda environment '$ENV_NAME'."

	# Check if the environment was successfully created and packages installed
	if [ $? -eq 0 ]; then
	    echo "Environment '$ENV_NAME' created and packages installed successfully."
	else
	    echo "Failed to install packages from requirements.txt"
	    exit 1
	fi
}

# Setup Python environment with Anaconda
setup_python_environment() {
	# Generate requirements.txt inside a temporary Docker container
	docker run --rm --platform linux/amd64 -v "$REQUIREMENTS_DIR":/tmp "$DOCKER_IMAGE" \
	    sh -c "pip freeze > /tmp/requirements.txt" 

	    # Append additional required packages to requirements.txt
    sed -i '' '/^polars==0\.14\.1$/d' "$REQUIREMENTS_DIR/requirements.txt"
    echo "mxnet" >> "$REQUIREMENTS_DIR/requirements.txt"
    echo "gluonts" >> "$REQUIREMENTS_DIR/requirements.txt"
    echo "pathlib" >> "$REQUIREMENTS_DIR/requirements.txt"
    echo "polars==1.0.0" >> "$REQUIREMENTS_DIR/requirements.txt"

    PYTHON_VERSION=$(docker run --rm --platform linux/amd64 "$DOCKER_IMAGE" python3 --version)

	PYTHON_VERSION=$(echo $PYTHON_VERSION | sed 's/Python //' | sed 's/\.[0-9]*$//')

	# Check if the requirements.txt was successfully generated
	if [ ! -f "$REQUIREMENTS_DIR/requirements.txt" ]; then
	    echo "Failed to generate requirements.txt"
	    exit 1
	fi

	# Source Conda's script to enable 'conda' commands in the script
	source "$HOME/anaconda3/etc/profile.d/conda.sh"

	# Handle the Conda environment
	if conda env list | grep -q "^$ENV_NAME\s"; then
	    echo "Environment '$ENV_NAME' exists. Removing it..."
	    conda env remove -n "$ENV_NAME" --yes
	fi

	echo "Creating new environment '$ENV_NAME'..."

	# Command to create a new Conda environment and install packages, output redirected to /dev/null
	conda create -n "$ENV_NAME" python=$PYTHON_VERSION --yes 
	conda activate "$ENV_NAME"
	pip install -r "$REQUIREMENTS_DIR/requirements.txt" 

	# Specifically for Jupyter interaction, if desired.
	pip install ipykernel 

	acquire_install_environmental_variables
}

handle_docker_image_for_r_packages() {
    echo "Extracting R packages list from Docker image..."
    DOCKER_CONTAINER=$(docker run -d --platform linux/amd64 "$DOCKER_IMAGE" tail -f /dev/null) # Run container in detached mode
    docker exec $DOCKER_CONTAINER R --slave -e "write.csv(installed.packages()[,'Package'], '/r_packages_list.csv')"
    docker cp $DOCKER_CONTAINER:/r_packages_list.csv ./r_packages_list.csv
    docker stop $DOCKER_CONTAINER

    echo "Installing R packages locally..."
    R --slave -e "packages <- read.csv('r_packages_list.csv', stringsAsFactors = FALSE)\$x; new.packages <- packages[!(packages %in% installed.packages()[,'Package'])]; if(length(new.packages)) install.packages(new.packages)"
}

check_and_install_R() {
    # Check if R is installed
    if command -v R &> /dev/null; then
        echo "R is already set up."
    else
        echo "Setting up R..."

        if [[ "$PLATFORM" == "Darwin" ]]; then
            # For macOS: Download and install R
            R_VERSION=$(docker run --rm --platform linux/amd64 "$DOCKER_IMAGE" R --version | head -n 1 | awk '{print $3}')
            R_URL="https://cran.r-project.org/bin/macosx/base/R-${R_VERSION}.pkg"

            echo "Downloading R version ${R_VERSION}..."
            curl -O "${R_URL}"

            echo "Installing R..."
            sudo installer -pkg R-${R_VERSION}.pkg -target /

            # R setup completed, now handle Docker image for R packages
            handle_docker_image_for_r_packages

        elif [[ "$PLATFORM" == "Linux" ]]; then
            echo "Linux platform detected. Installing R..."
            # Add the CRAN repository for Ubuntu
            sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
            sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
            sudo apt-get update
            sudo apt-get install -y r-base

            # R setup completed, now handle Docker image for R packages
            handle_docker_image_for_r_packages
        else
            echo "Unsupported platform for automatic R installation."
            return 1
        fi
    fi

    GLOBAL_RPROFILE="$HOME/.Rprofile"
    if [ -f "$GLOBAL_RPROFILE" ]; then
        echo "Global .Rprofile exists. Clearing original contents and adding new setup."
    else
        echo "Creating global .Rprofile and adding required setup."
    fi

    # Overwrite .Rprofile with Python execution code
    cat <<EOT > "$GLOBAL_RPROFILE"
if (interactive()) {
  library(reticulate)
  
  py_code <- "
import subprocess
import os

command = 'source activate current_staging_environ && env'
proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, executable='/bin/bash')
out, err = proc.communicate()

for line in out.splitlines():
    key, value = line.decode('utf-8').split('=', 1)
    os.environ[key] = value
"

  py_run_string(py_code)
}
EOT

    echo "Updated global .Rprofile for Reticulate/Python code execution."

}

install_slack() {
  # Check if the OS is Darwin (macOS)
  if [[ "$(uname)" == "Darwin" ]]; then

    # Check if Slack is already installed
    if [[ ! -d "/Applications/Slack.app" ]]; then
      echo "Slack not found. Installing..."

      # Define the download URL for Slack
      local slack_url="https://downloads.slack-edge.com/releases/macos/4.27.156/prod/x64/Slack-4.27.156-macOS.dmg"
      local slack_dmg="Slack.dmg"

      # Download Slack
      echo "Downloading Slack..."
      curl -L $slack_url -o $slack_dmg

      # Mount the DMG file
      echo "Mounting DMG..."
      hdiutil attach $slack_dmg

      # Assuming the volume name is 'Slack', but this may need to be adjusted
      # Copy Slack to the Applications folder
      echo "Installing Slack..."
      cp -r /Volumes/Slack*/Slack.app /Applications

      # Unmount the DMG
      echo "Cleaning up..."
      hdiutil detach /Volumes/Slack*

      # Remove the downloaded DMG file
      rm $slack_dmg

      echo "Slack installation complete."
    else
      echo "Slack is already installed."
    fi
  else
    echo "This script is intended only for macOS. Exiting..."
  fi
}

install_outlook() {
  # Check if the OS is Darwin (macOS)
  if [[ "$(uname)" == "Darwin" ]]; then

    # Check if Outlook is already installed
    if [[ ! -d "/Applications/Microsoft Outlook.app" ]]; then
      echo "Microsoft Outlook not found. Installing..."

      # Define the download URL for Office 365 which includes Outlook
      # Note: This URL points to the Office 365 installer and may need to be updated
      local office_url="https://go.microsoft.com/fwlink/?linkid=525133"
      local office_pkg="OfficeInstaller.pkg"

      # Download Office 365
      echo "Downloading Office 365 (including Outlook)..."
      curl -L $office_url -o $office_pkg

      # Install the Office 365 package
      echo "Installing Office 365 (including Outlook)..."
      sudo installer -pkg $office_pkg -target /

      # Clean up the downloaded package
      echo "Cleaning up..."
      rm $office_pkg

      echo "Microsoft Outlook installation complete as part of Office 365."
    else
      echo "Microsoft Outlook is already installed."
    fi
  else
    echo "This script is intended only for macOS. Exiting..."
  fi
}


# Main execution flow
main() {
    ensure_software_installed
    install_anaconda
    update_etl_repository
    localize_repo_pathing
    extract_repo_scripts_from_shells
    retrieve_keys_from_jumpdrive
    prepare_docker_environment
    setup_python_environment
    check_and_install_R
    install_slack
    install_outlook

    echo "Setup and synchronization complete."
}

main "$@"