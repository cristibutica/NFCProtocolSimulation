function status = nfcDEP(initiator, target, snrdB)
    % NFCIP-1 Data Exchange Protocol
    % Reference: ISO/IEC 18092, section 12.6

    %   Copyright 2016-2017 The MathWorks, Inc.
    
    % Max length of Transport Data Field is 254. CMD1, CMD2 & PFB require 3
    % bytes. No NAD or DID, so no bytes used there. Hence, max length of user
    % data is 254-3
    userDataMaxLen = 254 - 3;
    userDataLen = length(initiator.UserData);
    nIter = ceil(userDataLen/userDataMaxLen);
    % Activate Multiple Information chaining in DEP
    activateMI = double((nIter>1));
    
    for k = 1:nIter
        userData = getUserData(initiator, userDataMaxLen);
        
        % Send user data in the information PDU
        txDEP_REQ = transmitInformationPDU(initiator, userData, activateMI);
        rxDEP_REQ = awgn(txDEP_REQ, snrdB, 'measured');
        txDEP_RES = receiveInformationPDU(target, rxDEP_REQ);
        % Target responds with info PDU if chaining is not activated
        % (activateMI==false) or with ACK/NACK PDU if chaining is activated.
        rxDEP_RES = awgn(txDEP_RES, snrdB, 'measured');
        recPDUType = receiveDEP_RES(initiator, rxDEP_RES);
        if (recPDUType == nfcDEP_PDU_Type.Information)
            % MI chaining not activated. Done with user data transmission.            
            nfcPrint.Heading2('All data transmitted from Initiator to Target. Exit DEP.');
            break;
        elseif (recPDUType == nfcDEP_PDU_Type.ACK_OR_NACK)
            % MI chaining activated. Continue user data transmission.
            continue;
        else
            % This should not happen
            coder.internal.errorIf(true, 'comm:NFC:InvalidPDUTypeDEP');
        end
    end
    status = true;
    resetPNI(initiator);
    resetPNI(target);
    
end