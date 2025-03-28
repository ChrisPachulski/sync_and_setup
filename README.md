Sync and Setup Shell Script

The sync_and_setup.sh script automates comprehensive environment setup tasks, ensuring consistency and efficiency across development workflows. This README provides an overview, setup instructions, and descriptions of its key components.

Overview

This script is designed to streamline environment setup, software installations, configuration synchronization, and dependency management. It covers setups for macOS and Linux environments, integrating tools such as Docker, Anaconda, Git, PostgreSQL, R, and productivity applications.

Getting Started

Prerequisites

macOS or Linux operating system

Basic familiarity with terminal commands

Administrative privileges (sudo access) for installations

Installation

Clone this repository to your local machine:

git clone git@github.com:your-username/environment-setup-script.git
cd environment-setup-script

Ensure the script has executable permissions:

chmod +x sync_and_setup.sh

Usage

Run the script using:

./sync_and_setup.sh

Key Components

1. Environment and Path Setup

Initializes directories and remote synchronization paths.

2. Package Installation Automation

Detects OS and installs essential packages (Docker, Git, PostgreSQL, Vim, Rsync).

3. Anaconda Environment Setup

Installs Miniconda, configures Python environments, and manages dependencies.

4. Git Repository Management

Clones or updates repositories, manages SSH key configurations.

5. File and Directory Synchronization

Synchronizes key files and staging directories using rsync.

6. Docker Management and Dependency Extraction

Manages Docker images, extracts dependencies to maintain environment consistency.

7. Script Localization and Management

Localizes production paths and extracts embedded Python and R scripts.

8. R and Reticulate Integration

Installs R and configures interoperability with Python through Reticulate.

9. Productivity Tool Automation

Installs productivity software such as Slack and Microsoft Outlook.

Benefits

Consistency: Ensures uniform setups across environments.

Efficiency: Automates repetitive tasks, reducing setup time.

Scalability: Adaptable to various projects with minimal modifications.

Reliability: Reduces human error in environment configuration.

Contributing

Contributions are welcome! Please submit pull requests or open issues to suggest improvements.

License

This project is licensed under the MIT License - see the LICENSE file for details.

