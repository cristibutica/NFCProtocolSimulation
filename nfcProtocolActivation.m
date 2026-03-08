function nfcProtocolActivation(initiator, target, snrdB)
    % NFCIP-1 Transport Protocol Activation
    % Reference: ISO/IEC 18092, section 12.5
    
    nfcPrint.NewLine;
    nfcPrint.Heading1('Start of Transport Protocol Activation');
    
    txATR_REQ = transmitATR_REQ(initiator);
    rxATR_REQ = awgn(txATR_REQ, snrdB, 'measured');
    
    txATR_RES = receiveATR_REQ(target, rxATR_REQ);
    rxATR_RES = awgn(txATR_RES, snrdB, 'measured');
    
    txPSL_REQ = receiveATR_RES(initiator, rxATR_RES);
    rxPSL_REQ = awgn(txPSL_REQ, snrdB, 'measured');
    txPSL_RES = receivePSL_REQ(target, rxPSL_REQ);
    
    status = receivePSL_RES(initiator, txPSL_RES);
    coder.internal.errorIf(~status, 'comm:NFC:TPActivationFailed');
    
    nfcPrint.Heading1('End of Transport Protocol Activation');    
end