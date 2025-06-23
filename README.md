# Python Offline Package Generator
A script for downloading python packages based on the python version and linux distro type

This is a simple script that will download and package the python wheel or source package in your requirements.txt file specific to the python version that is passed in. In some cases it's not possible to download python packages for a system that either blocks the repos or is not connected online. This script utilizes docker to create an environement for downloading the correct python wheel or source packages for the specific python version being used. Once downloaded, it packages them up into a `tar.gz` file to easily transfer them to the offline system.

## Prerequisites:
* Install Docker with Docker Buildkit locally
* Know the version of python being used on the offline system
* requirements.txt file with all required packages listed
* Debian or RHEL based system

## Usage:
1\. Make the script executable `chmod +x generate_offline_packages.sh`

2\. Run the script by passing it both the linux distro type and python version

**example**:
```
./generate_offline_packages.sh rpm 3.10.4
```

3\. Once complete, a package will be generated `offline_packages_<distro type>.tar.gz`

4\. Extract the packages to be installed

**example**:
```
tar -xzf offline_packages_rpm.tar.gz
```

Now you should have a directory with all of the wheel or source packages listed in your requirements.txt file and will work with the version of python you are using. 
