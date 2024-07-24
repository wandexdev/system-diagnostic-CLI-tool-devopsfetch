# The CLI Tool **devopsfetch**
![overview](images/devopsfetch.png)

## Overview
**DevOpsFetch** is a CLI tool designed for system monitoring and log management. It provides functionalities for managing Docker containers and images, viewing Nginx configurations, and monitoring user logins. This tool also includes a systemd service for continuous monitoring.
This type of tool is incredibly useful for system administrators and DevOps engineers to maintain oversight over system configurations and statuses, quickly diagnose issues, and ensure smooth operation of services

## Usage
- Clone the repository
```shell
:~$ git clone https://github.com/wandexdev/system-diagnostic-CLI-tool-devopsfetch.git
```

- Enter directory folder
```shell
:~$ cd system-diagnostic-CLI-tool-devopsfetch
```

- List the very two major files needed and make it executable
```shell
:~$ ls
:~S devopsfetch.sh  install_devopsfetch.sh
:~$ chmod +x devopsfetch.sh  install_devopsfetch.sh
```

- Run the install script with sudo priviledge
```shell
:~$ sudo bash install_devopsfetch.sh
```

- Once installation is done, a prompt similar to this indicates successful setup of **devopsfetch** tool
```shell
:~$ Yay! Wande's DevOpsFetch tool is installed and the monitoring service is started.
```

- Tool now available to use via 
```shell
:~S devopsfetch - <options>
```

## Features
It is currently equipped for the following options:
- `-p, --port` Display active ports
- `-u, --users` Display users and details about specific ones
- `-n, --nginx` Display Nginx configurations and domains
- `-d, --docker` Display Docker images and details about specific ones
- `-t, --time` Display system activities within a specified time range"
