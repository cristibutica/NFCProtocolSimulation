function nfcProtocolDeactivation(initiator, target, snrdB)
    % Transport Protocol Deactivation
    % Reference: ISO/IEC 18092, section 12.7

    nfcPrint.NewLine;
    nfcPrint.Heading1('Start of Transport Protocol Deactivation');

    txRLS_REQ = transmitRLS_REQ(initiator);
    rxRLS_REQ = awgn(txRLS_REQ, snrdB, 'measured');
    
    txRLS_RES = receiveRLS_REQ(target, rxRLS_REQ);
    rxRLS_RES = awgn(txRLS_RES, snrdB, 'measured');
    
    status = receiveRLS_RES(initiator, rxRLS_RES);
    coder.internal.errorIf(~status, 'comm:NFC:TPDeactivationFailed');
    
    nfcPrint.Heading1('End of Transport Protocol Deactivation');
end