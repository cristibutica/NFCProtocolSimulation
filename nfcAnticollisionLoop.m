function nfcAnticollisionLoop(initiator, target, snrdB)
    % Anticollision Loop
    % Reference: ISO/IEC 14443-3, section 6
    
    nfcPrint.NewLine;
    nfcPrint.Heading1('Start of Anticollision loop');
    
    % Start anticollision loop
    cascadeLevel = 1;
    targetRxAC = [];
    nfcPrint.CascadeLevel(cascadeLevel);
    [initiatorTxAC, newCascadeLevel, uidComplete, isoCompliantTarget] = ...
        antiCollisionLoop(initiator, targetRxAC, cascadeLevel);
    
    while (newCascadeLevel <= 3) && ~uidComplete
        
        nfcPrint.CascadeLevel(newCascadeLevel, cascadeLevel);
        cascadeLevel = newCascadeLevel;
        
        targetRxAC = awgn(initiatorTxAC, snrdB, 'measured');
        % Target's anticollision loop
        targetTxAC = antiCollisionLoop(target, targetRxAC);
        initiatorRxAC = awgn(targetTxAC, snrdB, 'measured');
        % Initiator's anticollision loop
        [initiatorTxAC, newCascadeLevel, uidComplete, isoCompliantTarget] = ...
            antiCollisionLoop(initiator, initiatorRxAC, cascadeLevel);
    end
    
    coder.internal.errorIf(~uidComplete, 'comm:NFC:IncompleteUID');
    coder.internal.errorIf(~isoCompliantTarget, ...
        'comm:NFC:TargetNotCompliantWithNFCIP1');
    
    nfcPrint.Heading1('End of Anticollision loop');
    nfcPrint.NewLine;    
    nfcPrint.Heading1(['Target compliant with NFCIP-1. '...
        'Continue with Transport Protocol Activation']);    
end