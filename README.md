# MazeRunner

## Overview

This repository contains the source code and documentation for an autonomous maze-solving robot built using an FPGA and System Verilog. The robot is equipped with various sensors and interfaces, including SPI for gyroscope configuration, infrared (IR) sensors for maze navigation, and UART for communication with a Bluetooth module.

## Features

- **Autonomous Maze Navigation:** Implemented a state machine to autonomously navigate through a maze, utilizing heading values obtained from a gyroscope and IR readings.

- **SPI Interface for Gyroscope:** Developed a SPI interface to configure and obtain heading readings from a gyroscope, contributing to precise navigation.

- **UART Communication with Bluetooth Module:** Engineered a UART interface to communicate with a Bluetooth module, enabling external control and commands. Commands include gyroscope calibration, heading/movement adjustments, and autonomous maze-solving initiation.

- **Test Benches and Validation:** Designed comprehensive test benches for both pre and post-synthesis validation. Ensured functionality and reliability before deploying the robot for maze testing.

- **Synthesis with Pipelining:** Synthesized System Verilog code using Synopsis with pipelining techniques to meet timing constraints and enhance performance.
