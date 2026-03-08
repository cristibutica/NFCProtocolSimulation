function nfcDataExchangeProtocol(initiator, target, snrdB)
    % Data Exchange Protocol
    % Reference: ISO/IEC 18092, section 12.6
    
    nfcPrint.NewLine;
    nfcPrint.Heading1('Start of Data Exchange Protocol (DEP)');
    
    status = nfcDEP(initiator, target, snrdB);
    coder.internal.errorIf(~status, 'nfc:NFC:DEPFailed');
    
    nfcPrint.Heading1('End of Data Exchange Protocol (DEP)');
    nfcPrint.NewLine;    
end
