# Getting a TACC Account through NFS ACCESS Nodes and Resource Allocation

## Overview

This guide walks through the process of obtaining a Texas Advanced Computing Center (TACC) account, getting access to HPC systems like Stampede3, and allocating computational resources for your autograding project through the ACCESS allocation system.

---

## Part 1: Creating a TACC User Account

### Step 1.1: Register at the TACC Account Portal

1. **Visit the TACC User Portal:**
   - Navigate to https://www.tacc.utexas.edu/
   - Click on **"Create TACC Account"** or go to https://portal.tacc.utexas.edu/

2. **Fill in Your Information:**
   - First and Last Name
   - Email address (institutional email recommended)
   - Password (strong password with 12+ characters, including uppercase, lowercase, numbers, and special characters)
   - Confirm password
   - Organization/Institution
   - Department
   - Job Title/Role (e.g., Professor, Researcher, Student)

3. **Accept Terms and Conditions:**
   - Read and accept the TACC Usage Policy
   - Accept the ORCID Privacy Policy (optional but recommended)

4. **Complete Registration:**
   - Click **Submit**
   - Check your email for a verification link
   - Click the verification link to activate your account

### Step 1.2: Set Up Multi-Factor Authentication (MFA)

For security, TACC requires Multi-Factor Authentication (MFA):

1. **Log in to Your TACC Account:**
   - Go to https://portal.tacc.utexas.edu/
   - Enter your username and password

2. **Enable MFA:**
   - Navigate to **Account Settings** → **Security**
   - Click **Enable Multi-Factor Authentication**
   - Install an authenticator app on your phone (Google Authenticator, Microsoft Authenticator, Duo, etc.)
   - Scan the QR code or enter the setup key manually
   - Enter the 6-digit code from your authenticator app to verify

3. **Save Backup Codes:**
   - Download and securely store your backup codes
   - These codes allow account recovery if you lose access to your authenticator app

---

## Part 2: Getting ACCESS Allocation through NFS ACCESS Nodes

### Overview of ACCESS

**ACCESS (Advanced Cyberinfrastructure Coordination Ecosystem: Services & Support)** is the National Science Foundation's access management system for HPC resources. It replaced the XSEDE system and provides allocations on multiple HPC systems, including TACC's Stampede3.

### Step 2.1: Determine Your Allocation Type

#### Educational Allocations (Recommended for Courses)

**Instructor Allocation (Education):**
- Designed for academic courses and training
- Typically 1,000 - 50,000 core-hours per academic year
- Must be requested by faculty members
- Faster approval process (1-2 weeks)
- Renewal typically annual

**Startup Allocation (Educational):**
- For faculty new to HPC computing
- Up to 100,000 core-hours
- Single fiscal year
- Good for pilot projects

**Research Allocations:**
- For research projects and advanced studies
- Flexible allocation sizes
- Competitive review process
- Multiple-year support options

### Step 2.2: Submit an ACCESS Allocation Request

#### For Education Allocations:

1. **Visit the ACCESS Portal:**
   - Go to https://access-ci.org/
   - Click on **"Submit an Allocation Request"**

2. **Create/Log into Your ACCESS Account:**
   - If this is your first time, create an ACCESS account with your TACC credentials
   - Your TACC username and password may be used

3. **Start a New Request:**
   - Click **"Create New Request"**
   - Select **"Education Allocation"** as the allocation type

4. **Fill in Project Details:**

   **Basic Information:**
   - **Allocation Title:** (e.g., "OpenCilk Autograding System for CS101")
   - **Project Type:** Select "Education"
   - **Education Level:** Select appropriate level (Undergraduate, Graduate, etc.)
   - **Institution:** Your university name
   - **Discipline:** Computer Science

   **Resource Request:**
   - **System(s):** Select **"Stampede3 (TACC)"**
   - **Compute Hours Requested:** 
     - For autograding: typically 10,000 - 50,000 core-hours per year
     - Formula: (number of students) × (submissions per student) × (average execution time in hours)
     - Example: 100 students × 20 submissions × 0.01 hours = 20,000 core-hours
   - **Storage (GB):** 
     - Recommended: 1,000 - 10,000 GB for course projects
   
   **Project Description:**
   - Explain the educational purpose
   - Example: "This allocation supports autograded programming assignments for our OpenCilk course. Students submit C/Cilk programs that are automatically compiled, executed, and graded on Stampede3."
   - Describe learning outcomes
   - Mention number of students and course level

5. **Research/Education Narrative:**
   - Describe how the resources will be used
   - Include specifics about the autograding pipeline
   - Explain the educational impact

6. **Principal Investigator (PI) Information:**
   - Your TACC username
   - Your institution
   - Your department
   - Your email

7. **Co-Investigators (Optional):**
   - Add graduate students or teaching assistants who will manage the allocation
   - They should have their own TACC accounts first

8. **Review and Submit:**
   - Double-check all information
   - Click **"Submit Request"**
   - Save the allocation request ID for reference

### Step 2.3: Allocation Approval and Setup

1. **Wait for Approval:**
   - Educational allocations typically approved within 1-2 weeks
   - You'll receive an email notification when approved
   - Check your ACCESS account dashboard for status updates

2. **Upon Approval:**
   - Log into your TACC Portal
   - You will now have access to Stampede3
   - Your home directory will be `/home/your_username`
   - Your work directory will be `/work/xxxxx/your_username` or `/scratch/xxxxx/your_username`

3. **Verify Access:**
   - Test SSH connection: `ssh your_username@stampede3.tacc.utexas.edu`
   - You should be prompted for your TACC password + MFA code

---

## Part 3: Setting Up Stampede3 Access

### Step 3.1: Generate SSH Keys (Recommended)

To avoid entering MFA codes repeatedly, generate SSH keys:

1. **Generate Key Pair on Your Local Machine:**
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_stampede3 -C "your_email@institution.edu"
   ```
   - Leave passphrase empty (or set one for added security)

2. **Add Public Key to Stampede3:**
   ```bash
   cat ~/.ssh/id_stampede3.pub | ssh your_username@stampede3.tacc.utexas.edu 'cat >> ~/.ssh/authorized_keys'
   ```
   - You'll need to provide your password + MFA code once

3. **Update Your SSH Config** (on your local machine):
   Create/edit `~/.ssh/config`:
   ```
   Host stampede3
       HostName stampede3.tacc.utexas.edu
       User your_username
       IdentityFile ~/.ssh/id_stampede3
       IdentitiesOnly yes
   ```

4. **Test Connection:**
   ```bash
   ssh stampede3
   ```
   - Should connect without password if no passphrase was set

### Step 3.2: Create Working Directories

1. **Connect to Stampede3:**
   ```bash
   ssh stampede3
   ```

2. **Create Project Directories:**
   ```bash
   # Navigate to your work directory (higher quota than home)
   cd /work/xxxxx/your_username
   
   # Create directories for TAPIS autograding
   mkdir -p tapis/apps
   mkdir -p tapis/jobs
   mkdir -p tapis/archive
   
   # Set appropriate permissions
   chmod 755 tapis/
   chmod 755 tapis/apps/
   chmod 755 tapis/jobs/
   ```

3. **Copy Project Files:**
   ```bash
   # Upload your autograder files (e.g., runner scripts)
   scp -r ./Fib-Stampede stampede3:/work/xxxxx/your_username/tapis/
   ```

---

## Part 4: Important Notes and Best Practices

### Resource Management

1. **Monitor Your Usage:**
   - Use `sacct` command on Stampede3 to check job history
   - Log into ACCESS portal to see real-time allocation usage
   - Example: `sacct --format=JobID,JobName,CPUs,Elapsed,CPUTime`

2. **Request Renewal Before Expiration:**
   - Educational allocations typically renew annually
   - Submit renewal request 30 days before expiration
   - Log into ACCESS portal → "Manage Allocations" → "Request Renewal"

3. **Estimating Core-Hours:**
   - 1 core-hour = 1 CPU core running for 1 hour
   - Example: A 20-minute job (0.33 hours) on 4 cores = 1.32 core-hours
   - Allocations are typically per calendar year (January - December)

### Troubleshooting Common Issues

| Issue | Solution |
|-------|----------|
| "Permission denied (publickey,gssapi-keyex,gssapi-with-mic)" | Generate SSH keys or use SSH key with password-less login |
| "MFA code expired" | Use current code from authenticator app (codes expire every 30 seconds) |
| "Quota exceeded" | Check storage usage with `du -sh /work/xxxxx/your_username` |
| "Job submission failed" | Verify SLURM script syntax and resource requests don't exceed allocation |
| "Allocation expired" | Submit renewal request through ACCESS portal immediately |

### Security Reminders

- Never share your TACC password or MFA codes
- Don't commit SSH keys or credentials to version control
- Regularly review access logs in TACC portal
- Revoke access for users who no longer need it

---

## Part 5: Integration with TAPIS Registration

After completing steps above, you're ready to register your TAPIS system and app:

1. **Update `register_system.py`:**
   - Set `username = "your_tacc_username"`
   - Set `jobWorkingDir = "/work/xxxxx/your_username/tapis/jobs"`
   - Set `host = "stampede3.tacc.utexas.edu"`

2. **Update `register_fork_app.py`:**
   - Use the same TACC credentials
   - Point to system registered in Step 1

3. **See `README.md` in this directory for TAPIS registration details**

---

## Additional Resources

- **TACC Documentation:** https://docs.tacc.utexas.edu/
- **Stampede3 User Guide:** https://docs.tacc.utexas.edu/hpc/stampede3/
- **ACCESS Portal:** https://access-ci.org/
- **TACC Account Portal:** https://portal.tacc.utexas.edu/
- **Getting Help:** Contact TACC support at help@tacc.utexas.edu or use the TACC help desk

---

