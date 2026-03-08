function NFC_GUI
    fig = uifigure('Name', 'NFC Simulation', 'Position', [800 500 800 700]);
    
    fig2 = uifigure('Name', 'Simulation of axATQA and rxATQA', 'Position', [300 200 1200 700]);
    axTxATQA = axes(fig2, 'Position', [0.05, 0.25, 0.4, 0.6]);
    axRxATQA = axes(fig2, 'Position', [0.55, 0.25, 0.4, 0.6]);

    xlabel(axTxATQA, 'Time [secs]');
    ylabel(axTxATQA, 'Amplitude');
    title(axTxATQA, 'axATQA');

    xlabel(axRxATQA, 'Time [secs]');
    ylabel(axRxATQA, 'Amplitude');
    title(axRxATQA, 'rxATQA');

    uilabel(fig, 'Text', 'SNR (dB):', 'Position', [500 110 80 20]);
    snrSlider = uislider(fig, 'Limits', [0 100], 'Position', [570 120 150 3], 'Value', 50);
    
    ax = axes(fig, 'Position', [0.1, 0.35, 0.8, 0.6]);
    xlabel(ax, 'SNR (dB)');
    ylabel(ax, 'Bit Error Rate (BER)');
    title(ax, 'Simulation Performance');

    % Create LED panel (simulated LED)
    uilabel(fig, 'Text', 'State of Transmission:', 'Position', [500 150 120 20]);
    circleAx = uiaxes(fig, 'Position', [605 130 50 50]);
    circleAx.Interactions = [];
    hold(circleAx, 'off');
    axis(circleAx, 'off');
    led = rectangle(circleAx, 'Position', [10 10 30 30], 'Curvature', [1, 1], 'FaceColor', 'red');

    statusText = uitextarea(fig, 'Position', [20 50 450 140], 'Editable', 'off');

    startButton = uibutton(fig, 'Text', 'Start Simulation', ...
        'Position', [570 50 150 30], ...
        'ButtonPushedFcn', @(btn, event) runSimulation(snrSlider.Value, ax, statusText, led, axRxATQA, axTxATQA));
end
