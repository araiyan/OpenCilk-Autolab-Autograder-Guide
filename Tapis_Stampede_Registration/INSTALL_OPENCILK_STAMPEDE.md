# Installing OpenCilk on Stampede3

This guide shows the simplest way to set up OpenCilk in your Stampede3 work directory so your Cilk programs can be compiled and run from TAPIS jobs.

## 1. Log in to Stampede3

Connect to your TACC account first:

```bash
ssh your_username@stampede3.tacc.utexas.edu
```

If you have not created a TACC account yet, follow the TACC setup guide in this folder first.

## 2. Create a work directory

Use your work filesystem for project files and build output:

```bash
cd $WORK
mkdir -p opencilk
```

## 3. Download OpenCilk

use wget to install the latest shell script to install OpenCilk from the official [OpenCilk Install Guide](https://www.opencilk.org/doc/users-guide/install/)

## 4. Install OpenCilk

```bash
sh opencilk-3.0.0-x86_64-linux-gnu-ubuntu-24.04.sh --prefix=$WORK/opencilk --exclude-subdir
```

Note: This command might change with each update to OpenCilk so please follow the correct format from the official OpenCilk Guide as mentioned above.

## 5. Set up your Environment

To use the compiler, you need to add it to your PATH. You can add this to your ~/.bashrc to make it permanent:

Note: make sure the path is correct, it could change depending on the version of OpenCilk

```bash
export PATH=$WORK/opencilk/OpenCilk-3.0.0-x86_64-linux-gnu-ubuntu-20.04/bin:$PATH
export LD_LIBRARY_PATH=$WORK/opencilk/OpenCilk-3.0.0-x86_64-linux-gnu-ubuntu-20.04/lib:$LD_LIBRARY_PATH
```





