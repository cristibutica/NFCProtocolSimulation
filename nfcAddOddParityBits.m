function msgWithParityBits = nfcAddOddParityBits(msg)
    % Add odd parity bit to MSG as per the specification of ISO/IEC
    % 14443-3, for Type A air interface. See section 6.2.3.2 in the spec
    % for details. Output MSGWITHPARITYBITS contains odd parity bit
    % appended at the end of input MSG.
    %
    % 1st bit in MSG is the start of the message i.e. it is to
    % be transmitted right after 'start of communication' sequence.

    %   Copyright 2016-2021 The MathWorks, Inc.
        
    % msg must have full bytes i.e. length(msg) must be multiple of 8
    msgLength = length(msg);
    coder.internal.errorIf(~((msgLength > 0) && (mod(msgLength, 8) == 0)), ...
        'comm:NFC:InvalidInputLength');
        
    nBytes = msgLength/8;
    inpSize = size(msg);
    outSize = inpSize;
    outSize(1) = msgLength + nBytes;
    msgWithParityBits = coder.nullcopy(zeros(outSize, 'like', msg));
    
    for k = 1:nBytes
        currMsgIdx = (k-1)*8 + (1:8);
        % Account for parity bit addition
        currMsgPBIdx = currMsgIdx + (k-1);
        currByte = msg(currMsgIdx, 1);
        msgWithParityBits(currMsgPBIdx, 1) = currByte;
        % Make sum([msgByte, ParityBit]) odd
        msgWithParityBits(currMsgPBIdx(8)+1, 1) = (mod(sum(currByte), 2) == 0);
    end
    
end