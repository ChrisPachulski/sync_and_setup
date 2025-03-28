
# Sync and Setup Shell Script

The `sync_and_setup.sh` script automates comprehensive environment setup tasks, ensuring consistency and efficiency across development workflows.

---

## Overview

This script streamlines environment setup, software installations, configuration synchronization, and dependency management for macOS and Linux environments, integrating tools like Docker, Anaconda, Git, PostgreSQL, R, Slack, and Outlook.

---

## Getting Started

### Prerequisites

- macOS or Linux
- Terminal command knowledge
- Sudo access (administrative privileges)

### Installation

**Step 1: Clone the Repository**

```bash
git clone git@github.com:your-username/environment-setup-script.git
cd environment-setup-script
```

**Step 2: Set Executable Permissions**

```bash
chmod +x sync_and_setup.sh
```

### Usage

```bash
./sync_and_setup.sh
```

---

## Key Components

| Component                              | Description                                                               |
| -------------------------------------- | ------------------------------------------------------------------------- |
| **Environment and Path Setup**         | Initializes directories and paths for synchronization.                    |
| **Package Installation Automation**    | OS detection and installation of Docker, Git, PostgreSQL, etc.            |
| **Anaconda Environment Setup**         | Installs Miniconda, configures Python environments, manages dependencies. |
| **Git Repository Management**          | Automates Git repo cloning, updating, and SSH configuration.              |
| **File and Directory Synchronization** | Uses `rsync` for syncing keys and staging directories.                    |
| **Docker Management**                  | Handles Docker images, extracts Python and R dependencies.                |
| **Script Localization**                | Converts production paths to local paths and extracts scripts.            |
| **R and Reticulate Integration**       | Installs R and sets up Python interoperability with Reticulate.           |
| **Productivity Tool Automation**       | Installs Slack and Outlook for macOS environments.                        |

---

## Benefits

- ✅ **Consistency**: Uniform setups across environments.
- ✅ **Efficiency**: Automated repetitive tasks.
- ✅ **Scalability**: Easily adaptable for multiple projects.
- ✅ **Reliability**: Minimizes human error.


