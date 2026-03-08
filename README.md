# NFC Protocol Simulation & Performance Analysis

## Overview
This repository contains a MATLAB-based simulation of the Near Field Communication (NFC) protocol. The project models passive data transmission between an Initiator (acting as a reader/writer) and a Target (emulating a contactless card). It strictly adheres to the ISO/IEC 14443-2 standard for Type A interfaces, operating at a data rate of 106 kbps.

## Key Features
* **Initiator Modulation:** Implements 100% Amplitude Shift Keying (ASK) using Modified Miller coding.
* **Target Modulation:** Simulates Load Modulation using an 847.5 kHz subcarrier frequency with 10% ASK and Manchester coding.
* **Complete Protocol Lifecycle:** Programmatically executes the entire data exchange process, including Initialization, Anticollision Loop, Protocol Activation, Data Exchange, and Protocol Deactivation.
* **Performance Analysis (SNR vs. BER):** Calculates and plots the Bit Error Rate (BER) against the Signal-to-Noise Ratio (SNR) to evaluate transmission reliability under noise.
* **Interactive MATLAB GUI:** Features a custom Graphical User Interface with real-time tracking, an adjustable SNR slider, a status text log for exception handling, and a visual LED indicator.

## Prerequisites
* **MATLAB:** The project utilizes standard MATLAB GUI components like `uifigure`, `uislider`, and `uiaxes`.

## Usage
1. Clone the repository to your local machine.
2. Open MATLAB and navigate to the repository folder.
3. Run the main GUI script from the command window or by opening the file and clicking **Run**.
4. **Using the GUI:**
   * Adjust the maximum limit for the SNR domain using the slider (default is 50 dB, range 0-100).
   * Click the **Start Simulation** button to initiate the protocol.
   * Observe the generated SNR vs. BER plot on the main axes.
   * Monitor the transmission lifecycle in the status text box at the bottom left.
   * The visual LED will turn **Green** if the data exchange is successful, or remain **Red** if errors/exceptions occur during the simulation.

## Theoretical Background
In NFC passive communication, the Initiator generates an active electromagnetic field that powers the Target. 
* To send data to the Target, the Initiator uses 100% ASK, where a bit "1" has maximum amplitude and a bit "0" drops the amplitude to zero. 
* To send data back, the Target modulates the incident field (Load Modulation). It uses 10% ASK, meaning the amplitude only fluctuates by about 10% (from maximum amplitude for "1" to 90% amplitude for "0"), ensuring continuous power synchronization.
