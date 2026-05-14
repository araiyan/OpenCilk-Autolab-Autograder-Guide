---
title: OpenCilk Autograder
description: A guide for configuring Autolab and Tapis-based autograding for OpenCilk Cilk programs.
theme: minima
---

# OpenCilk Autolab Autograder Guide
A repo dedicated to providing a Guide for configuring Autolab for autograding Cilk Programs

# Setting up OpenCilk Autograder for Autolab

Hello everyone, I created this guide to provide step-by-step instructions for setting up an OpenCilk autograding backend for Autolab. It is designed to help instructors teaching Software Performance Engineering and related courses easily autograde students' Cilk programs and manage their classroom.

The guide covers the complete setup process: installing Autolab using the official documentation, configuring the autograding Docker container with OpenCilk support, and creating your first Cilk assessment.

## Autolab Setup

### Docker Compose Install (Recommended)

For Setting up Autolab itself I recommend following the official Autolab Docker Compose setup that can be found here -> [Autolab](https://docs.autolabproject.com/installation/docker-compose/)

**Important Note:** Follow all the step from step 1 to step 13 until you finish setting up TLS or decide not to set up TLS for testing purposes. I'll go over setting up the Tango autograding image seperately.


This will go over Autolab + Tango Docker Compose Installation. The is a straightforward guide to setup Autolab in a Virtual Machine and Setting up Nginx within autolab to host the frontend of Autolab in your own Domain.

Once you have set everything up until step 13, simply run ```$ docker compose up -d``` to run the frontend and verify you can correctly access the website from your Domain.

### Setting up Tango

The updated Autograding Dockerfile can be found here: [Dockerfile](https://github.com/autolab/Tango/blob/2e591c25371e64550f916c795e3094ae2a963761/vmms/Dockerfile)

Simply replace autolab-docker/Tango/vmms/Dockerfile with the dockerfile in in the link above. This is the Dockerfile image thats going to build the OpenCilk Autograding Image.

Then run the following commands to build the autograding image:  
```$ cd /<path-to-docker-compose-installation>```  
```$ docker build -t autograding_image Tango/vmms/```

 Now everything should be setup to run OpenCilk Autograding backend with Autolab. Start everything up if not already: ```$ docker compose up -d```

## Making your First OpenCilk Assessment

First I'll provide a sample OpenCilk Assessment and the files you need to set the assignment up. This was you can also test to make sure Opencilk autograding backend if fully functional on your end. Then I'll explain each sample files and what they are doing so you could make your own OpenCilk Assessment

### Setting up OpenCilk Fib Assessment

#### Git Clone:
cd into a directory where you would like to store the sample assessment. This can be anywhere from which your accessing the Autolab Frontend website (not the virtual server autolab backend is running on)

Then clone this repo by running the following command:  
```$ git clone https://github.com/araiyan/Autolab-OpenCilk-Assessments.git```

#### Create Autolab Assessment:

1. Login to Autolab from your Domain
2. Click on **Manage Autolab** at the Top Right
   - **Create New Course**
   - Give your course a name, semester and input the instructor email
   - Then click **Create Course**
3. You should not have a course in the main page. Click on your course page
   - Click on the **AUTOLAB** logo at the top left
   - From Courses section click on the recently created course
4. Click on **Install Assessment**
   - Were using the first option, **Create New Assessment** under Create from scratch
5. Configure the assessment
   - Name it Fib Lab
   - Create a new category, (Cilk Assessment)
   - keep the rest of the configuration the same and hit **Create Assessment**
6. Now from the Assessment page click on **Edit assessment** under Admin Options
7. Configure the Autograder
   - At the bottom of the basic page look at under Modules Used and click on the plus symbol next to **Autograder**
   - Make sure under VM image it says autograding_image. This is the same openCilk Autograding image we had built earlier
   - Under Autograder Makefile click **Choose File**
     - Now move to the directory in which you had initially cloned Autolab-OpenCilk-Assessments
     - Go inside the Fib directory then choose the **autograde-Makefile**
   - Now under Autograder Tar click **Choose File**
     - Go back to the same direcotry and choose **autograde.tar**
   - Now Click **Save Settings** to save the current autograder configuration
   - Then go back to the Edit Assessments page by clicking on **Edit Assessment** at the top left corner on the left of Autograder Settings tab
8. Configure Handin
   - Click on the **Handin** Tab
   - Under Handin filename name the handin file **fib.c** (This is the file we want students to submit)
9. Now lets configure the scoring 
   - Click on the **Problems** Tab
   - Click **Add Problem**
     - Name it **Correctness** (This is the same name our driver.sh looks for inside the autograder)
     - set Max score to be 100
     - The click **Save Problem**

Everything should be setup now, lets test out our system

#### Testing the OpenCilk Assessment
1. Click on the Assignment name at the top left corner for the page on the left of Edit Assessment
2. From this Assessment page click on the submission box
3. Now navigate back to the Autolab-OpenCilk-Assessments/Fib directory
4. Choose the file named fib.c (This is the correct implementation of the assessment)
5. Click on *I affirm that I have compiled...*
6. Hit **Submit**
7. After 1 second click on **View Source**
    - You should be able to see the Autograder output now and see grades at the middle right side of your screen
8. It should say Correctness 100/100 under the Grades tab

## Making Custom OpenCilk Assessments

To create custom OpenCilk Assessments for Autolab, first consult the comprehensive guide on building Autolab Assessments in the official documentation -> [Guide for Lab Authors](https://docs.autolabproject.com/lab/)

I'll now give short summaries of a few important files to keep in mind when creating an Autolab OpenCilk Assessment

### autograde.tar

This is the grading environment for testing the students submission. This can include:
 - an empty c file that will be later replaced by students submission
 - driver.sh which will grade the students submission
 - Makefile which contains the code to build the student's submitted cilk program using opencilk/bin/clang

### autograde-Makefile

This is the file first Makefile Tango launches up when a students submit their job to Autolab. The make file unzips our assessment environment then copies student's submitted CilkFile inside our grading directory and runs driver.sh which is the main grading shell script that will assess students submission

### driver.sh

This is the main grading shell script that compiles the student's Cilk program and runs it through test cases. It evaluates the program's correctness by comparing actual output against expected results. The script can be customized to test multiple scenarios and inputs depending on the specific requirements of the Cilk program being assessed. It outputs scores for each problem (e.g., "Correctness") that Autolab uses to calculate the final grade.

# Setting up Stampede3 Auto Assessment Submission
If you would rather have your assessments be graded inside an HPC machine for performance analysis, please do the following in order, to correctly setup Stampede3 inside of Texas Advanced Computing Center to accept Cilk FORK Job submissions.

First, if you don't have a TACC account yet, follow [this guide](./Tapis_Stampede_Registration/GETTING_TACC.md) to create one.

Next, you'll need to install and configure OpenCilk in your Stampede3 work directory to support Cilk program compilation and execution. Detailed setup instructions are provided in [Install OpenCilk to Stampede](./Tapis_Stampede_Registration/INSTALL_OPENCILK_STAMPEDE.md).

Finally, once you've completed the TACC account setup and OpenCilk installation, follow the [TAPIS registration instructions](./Tapis_Stampede_Registration/README.md) to configure TAPIS as your orchestration layer. This enables automatic submission and execution of Cilk jobs through your autograder.

## Testing Stampede3 Setup

Once you have setup your Stampede3 node with Tapis to recieve Fork job submission, run the following to test whethere your setup is fully functional

### For Windows:

```bash
$env:TAPIS_USERNAME='your_username'; $env:TAPIS_PASSWORD='your_password'; $env:TAPIS_APP_VERSION='1.0.1'; $env:TAPIS_RUNNER_SCRIPT='tapis_run_fib.sh'; $env:TAPIS_REQUIRE_OPENCILK_CC='1';
bash ./local-submit.sh
```

### For Linux/bash:

```bash
TAPIS_USERNAME='your_username' TAPIS_PASSWORD='your_password' TAPIS_APP_VERSION='1.0.1' TAPIS_RUNNER_SCRIPT='tapis_run_fib.sh' python register_fork_app.py
```
### Then run local submission:

```bash
bash ./local-submit.sh
```

### Or with custom settings:
```bash
TAPIS_APP_ID='fibonacci-fork-app' TAPIS_APP_VERSION='1.0.1' FIB_INPUT='20' bash ./local-submit.sh
```

# Autograding Assignments from Stampede
Now that you have stampede3 setup to recieve autograding submissions all thats left is to package an assignment that works around autolab to submits jobs to stampede3. A sample Autolab Assessment is provided for you here: [Fibonacci](https://github.com/araiyan/OpenCilk-Autolab-Autograder-Guide/tree/main/Fib%20-%20Stampede/fib-handout)

### Setting up Sample Fib Assessment
Once you have downloaded the sample assessment first make a copy of the env.example by running this command:
```cp .env.example .env```

Afterwords add your TACC Username, password, the Tapis APP ID you previously registered and the correct app version for this app.
If your unsure what apps you have currently in your system referer back to Tapis_Stampede_Registration folder and run the check_register_app.py to find all your currently registered apps under your account.  
Once you've set up the environment varibles zip your fib-handout folder into tar and name it **autograde.tar** Note: the name here is important because Tango autograder is set up to accept a compressed file with this exact name.  
You should be fimiliar with Autolab assessment creation at this point. Follow the previous steps in this guide to create a new Assessment, name it whatever you like and when your setting up the autograder in the autograding step of the guide simply replace the older autograde.tar files with this new one.  
Thats it! You should be all setup to autograde this cilk program now. We have provided with a sample solution here: [fib.c](https://github.com/araiyan/OpenCilk-Autolab-Autograder-Guide/blob/main/Fib%20-%20Stampede/fib.c)  
Once you submit the assessment you should see a score for the assessment. If you want to also see a performance scoring for your assessment go back to Autolab -> autograder and add another scoring section and name it *Performance* and you should also see a performance scoring for your future assessments!

### Debugging
If your seeing an error in your autograder at this point and it keeps giving you 0 score, click on the log message that pops up at the middle top of Autolab whenever you submit an assignment, it should lead you to the autograding logs and help you see where its failing. Feel free to reach out to us if your having trouble solving any issues!