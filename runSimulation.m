function runSimulation(snrdB, ax, statusText, led, axRxATQA, axTxATQA)
    
    initiator = evalin('base', 'initiator');
    target = evalin('base', 'target'); 

    led.FaceColor = "red";

    % Define a range for SNR (in dB)
    snrRange = 0:1:snrdB;  % Example SNR range from 0 to 30 dB
    
    % Initialize the BER array
    ber = zeros(size(snrRange)); 
    
    % Calculate BER for each SNR value in the range
    for i = 1:length(snrRange)
        snr = 10^(snrRange(i) / 10);  % Convert SNR from dB to linear scale
        ber(i) = (1/2) * qfunc(sqrt(2 * snr));  % Calculate BER for Modified Miller ASK
    end
    
    % Plot the results
    plot(ax, snrRange, ber, '-o');
    xlabel(ax, 'SNR (dB)');
    ylabel(ax, 'Bit Error Rate (BER)');
    title(ax, 'Simulation Performance');

    fprintf('\nSelected SNR: %.2f dB\n', snrdB);

    statusText.Value = "Starting NFC Simulation...";
    pause(0.5);

    try
        nfcInitialization(initiator, target, snrdB, axRxATQA, axTxATQA);
        statusText.Value = "Initialization Complete.";
        pause(0.5);

        nfcAnticollisionLoop(initiator, target, snrdB);
        newText = statusText.Value + ", Anticollision Successful.";
        statusText.Value = newText;
        pause(0.5);

        nfcProtocolActivation(initiator, target, snrdB);
        newText = newText + ", Protocol Activated."
        statusText.Value = newText;
        pause(0.5);

        nfcDataExchangeProtocol(initiator, target, snrdB);
        newText = newText + ", Data Exchange Successful!"
        statusText.Value = newText;
        pause(0.5);

        nfcProtocolDeactivation(initiator, target, snrdB);
        newText = newText + ", Protocol Deactivated. Simulation Complete!"
        statusText.Value = newText;

        led.FaceColor = "green";
    catch ME
        %statusText.Value = getReport(ME);
        statusText.Value = sprintf("Error caused by: %s : %s", ME.identifier, ME.message);
    end
end
