function [isParityValid, msg] = nfcCheckOddParityBits(msgWithParityBits)
    % Check odd parity bit in input MSGWITHPARITYBITS as per the
    % specification of ISO/IEC 14443-3, for Type A air interface. See
    % section 6.2.3.2 in the spec for details. Output ISPARITYVALID
    % indicates if parity check passed or failed. Output MSG contains data
    % with out the odd parity bit.
    % 
    % 1st bit in MSGWITHPARITYBITS is the start of the message i.e. it is 
    % transmitted/received right after 'start of communication' sequence.

    %   Copyright 2016-2017 The MathWorks, Inc.

    isParityValid = false;
    msg = [];
    
    % input must be of length that is multiple of 9 (8 bits + 1 parity bit)
    msgPBLength = length(msgWithParityBits);
    if ((msgPBLength == 0) || (mod(msgPBLength, 9) ~= 0))
        return
    end
    
    nBytes = msgPBLength/9;
    inpSize = size(msgPBLength);
    outSize = inpSize;
    outSize(1) = nBytes * 8;
    tmpMsg = coder.nullcopy(zeros(outSize, 'like', msgWithParityBits));
    
    for k = 1:nBytes
        currMsgPBIdx = (k-1)*9 + (1:9);
        currByteWithPB = msgWithParityBits(currMsgPBIdx, 1);
        % Ensure that sum([msgByte, ParityBit]) is odd
        isParityValid = (mod(sum(currByteWithPB), 2) == 1);
        if ~isParityValid
            % break at the first failed parity check
            break;
        end
        currMsgIdx = (k-1)*8 + (1:8);
        tmpMsg(currMsgIdx, 1) = currByteWithPB(1:8, 1);
    end
    
    if isParityValid
        % send out the msg
        msg = tmpMsg;
    end
    
end