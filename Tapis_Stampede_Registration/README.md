# TAPIS Registration Guide

## Overview

**Important Note:** For each Assessment you create for your class, you need to register a separate app. Registering the TAPIS System is only a one-time setup.

## Prerequisites

Before starting, ensure you have:
- Python 3.7+
- `tapipy` library installed: `pip install tapipy`
- Valid TAPIS credentials (username and password)
- Access to the target HPC system (e.g., Stampede3)
- SSH key for the HPC system (placed in the same directory as these scripts)

## Step 1: Register a TAPIS System (One-Time Setup)

The execution system only needs to be registered once. This tells TAPIS how to connect to your HPC system.

### Configuration

Edit `register_system.py` and update these fields:

```python
TENANT_URL = "https://tacc.tapis.io"          # TAPIS tenant URL
USERNAME = "your_username"                     # Your TAPIS username
PASSWORD = "your_password"                     # Your TAPIS password
system_id = "stampede3.exec.your_username"    # Unique system ID
host = "stampede3.tacc.utexas.edu"            # HPC system hostname
effectiveUserId = "your_username"              # Your HPC username
jobWorkingDir = "/scratch/xxxxx/your_username/tapis/jobs"  # Job working directory
```

### Running the Registration

#### Windows PowerShell:
```powershell
cd ".\Tapis_Stampede_Regestration"
python register_system.py
```

#### Linux/macOS:
```bash
cd ./Tapis_Stampede_Regestration
python register_system.py
```

**Expected Output:**
```
Success! System 'stampede3.exec.your_username' is now registered.
```

---

## Step 2: Register an App (For Each Assessment)

Create a new app definition for each assessment/assignment you want to run on TAPIS.

### Configuration

Edit `register_fork_app.py` and set environment variables or update these fields:

```python
TAPIS_BASE_URL = "https://tacc.tapis.io"
TAPIS_USERNAME = "your_username"
TAPIS_PASSWORD = "your_password"
TAPIS_APP_ID = "fibonacci-fork-app"            # Unique app ID
TAPIS_APP_VERSION = "1.0.1"                   # Version number
TAPIS_EXEC_SYSTEM_ID = "stampede3.exec.your_username"  # System ID from Step 1
TAPIS_APP_DESCRIPTION = "Your app description"
TAPIS_RUNNER_SCRIPT = "tapis_run_fib.sh"      # Your runner script
TAPIS_APP_BUNDLE_DIR = "scratch/xxxxx/your_username/tapis/apps"
```

### Running the App Registration

#### Windows PowerShell:
```powershell
cd ".\Tapis_Stampede_Regestration"

# Option 1: Set environment variables in PowerShell
$env:TAPIS_USERNAME = "your_username"
$env:TAPIS_PASSWORD = "your_password"
$env:TAPIS_APP_ID = "my-app"
$env:TAPIS_APP_VERSION = "1.0.0"
$env:TAPIS_EXEC_SYSTEM_ID = "stampede3.exec.your_username"

python register_fork_app.py
```

#### Linux/macOS:
```bash
cd ./Tapis_Stampede_Regestration

# Option 1: Set environment variables
export TAPIS_USERNAME="your_username"
export TAPIS_PASSWORD="your_password"
export TAPIS_APP_ID="my-app"
export TAPIS_APP_VERSION="1.0.0"
export TAPIS_EXEC_SYSTEM_ID="stampede3.exec.your_username"

python register_fork_app.py

# Option 2: Use inline environment variables
TAPIS_USERNAME="your_username" \
TAPIS_PASSWORD="your_password" \
TAPIS_APP_ID="my-app" \
python register_fork_app.py
```

**Expected Output:**
```
Uploaded ZIP runtime bundle to /path/to/bundle
Success! Created app version my-app:1.0.0
```

Or if the version already exists:
```
Uploaded ZIP runtime bundle to /path/to/bundle
Success! Updated existing app version my-app:1.0.0
```

---

## Step 3: Check Registered Apps

Verify that your app and system are properly registered in TAPIS.

### Configuration

Edit `check_registered_app.py` and update credentials:

```python
TENANT_URL = "https://tacc.tapis.io"
USERNAME = "your_username"
PASSWORD = "your_password"
```

The script will:
1. List all registered apps for your account
2. Show each app's ID, version, and execution system
3. Attempt to register a test app (optional, can be modified)

### Running the Check

#### Windows PowerShell:
```powershell
cd ".\Tapis_Stampede_Regestration"
python check_registered_app.py
```

#### Linux/macOS:
```bash
cd ./Tapis_Stampede_Regestration
python check_registered_app.py
```

**Expected Output:**
```
ID: fibonacci-fork-app | Version: 1.0.2 | ExecSystem: N/A
ID: my-app | Version: 1.0.0 | ExecSystem: N/A
App registered successfully!
```

---

## Environment Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `TAPIS_BASE_URL` | TAPIS tenant URL | `https://tacc.tapis.io` |
| `TAPIS_USERNAME` | Username for authentication | **Required** |
| `TAPIS_PASSWORD` | Password for authentication | **Required** |
| `TAPIS_APP_ID` | Unique application identifier | `fibonacci-fork-app` |
| `TAPIS_APP_VERSION` | Application version | `1.0.1` |
| `TAPIS_EXEC_SYSTEM_ID` | Execution system ID | `stampede3.exec.raiyan` |
| `TAPIS_APP_DESCRIPTION` | Description of the app | `Fibonacci calculation via Fork on Stampede3...` |
| `TAPIS_RUNNER_SCRIPT` | Path to runner script | `tapis_run_fib.sh` |
| `TAPIS_APP_BUNDLE_DIR` | Remote directory for app bundle | `scratch/11412/araiyan/tapis/apps` |

---

## Troubleshooting

### Authentication Errors
- Verify your TAPIS credentials are correct
- Check that your account has access to the HPC system
- Ensure your password doesn't contain special characters that need escaping

### System Registration Failed
- Verify the system hostname is correct
- Check that SSH access is properly configured
- Ensure the working directory path exists on the HPC system
- Confirm your effective user ID is correct

### App Registration Failed
- Verify the execution system ID exists (run `check_registered_app.py`)
- Ensure the runner script file exists
- Check that the app bundle directory is writable
- Verify the app ID is unique or use a different version number

### SSH Key Issues
- Ensure your SSH private/public key pair is in the script directory
- Keys should be named `tacc-key` (private) and `tacc-key.pub` (public)
- Set proper permissions: `chmod 600 tacc-key` (Linux/macOS)

---

## Example Workflow

```bash
# 1. Register system (one time)
python register_system.py

# 2. Create app for Assessment 1
export TAPIS_APP_ID="assessment-1-solution"
export TAPIS_APP_VERSION="1.0.0"
python register_fork_app.py

# 3. Create app for Assessment 2
export TAPIS_APP_ID="assessment-2-matrix"
export TAPIS_APP_VERSION="1.0.0"
python register_fork_app.py

# 4. Verify all apps are registered
python check_registered_app.py
```

---

## Notes

- Keep your TAPIS credentials secure and never commit them to version control
- Each app registration uploads files to the remote HPC system
- You can update an existing app by using the same ID but incrementing the version
- The runner script defines how your code is executed on the HPC system
- For updates to an app, consider incrementing `TAPIS_APP_VERSION` (e.g., 1.0.0 → 1.0.1)