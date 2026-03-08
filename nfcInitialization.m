function nfcInitialization(initiator, target, snrdB, axRxATQA, axTxATQA)
    % Initialization and anticollision
    % Reference: ISO/IEC 14443-3, section 6

    cla(axRxATQA);
    hold on;

    cla(axTxATQA);
    hold on;

    txREQA = transmitREQA(initiator);

    sigPower = sum(abs(txREQA(:)).^2)/numel(txREQA);  % Puterea în watti
    sigPower_dBm = 10*log10(sigPower/0.001);
    fprintf('Puterea semnalului transmis masurata: %.8f dBm\n', sigPower_dBm);

    [rxREQA, noisevar] = awgn(txREQA, snrdB, 'measured');
    sigPowerRX = sum(abs(rxREQA(:)).^2)/numel(rxREQA);  % Puterea în watti
    sigPowerRX_dBm = 10*log10(sigPowerRX/0.001);
    fprintf('Puterea semnalului receptionat masurata: %.8f dBm\n', sigPowerRX_dBm);
    fprintf('Puterea zgomotului receptionat masurata: %.8f dBm\n', 10*log10(noisevar/0.001));
    % plot(txREQA);
    % plot(rxREQA);

    txATQA = receiveREQA(target, rxREQA);
    rxATQA = awgn(txATQA, snrdB, 'measured');
    
    timeTx = (0:length(txATQA) - 1) / (106e3 * 128); % Fs = bitRate * samplesPerSymbol
    plot(axTxATQA, timeTx, txATQA);
    xlabel(axTxATQA, 'Time [secs]');
    ylabel(axTxATQA, 'Amplitude');
    title(axTxATQA, 'TxATQA');
    hold off;

    timeRx = (0:length(rxATQA) - 1) / (106e3 * 128);
    plot(axRxATQA, timeRx, rxATQA);
    xlabel(axRxATQA, 'Time [secs]');
    ylabel(axRxATQA, 'Amplitude');
    title(axRxATQA, 'RxATQA');
    hold off;

    [isATQAValid, isCollisionDetected, isTargetCompliant] = ...
        receiveATQA(initiator, rxATQA);

    coder.internal.errorIf(~isATQAValid, 'comm:NFC:InvalidATQA');
    coder.internal.errorIf(isCollisionDetected, 'comm:NFC:CollisionATQA');
    coder.internal.errorIf(~isTargetCompliant, 'comm:NFC:TargetNotCompliant');    
end