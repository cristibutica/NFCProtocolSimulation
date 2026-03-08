function bcc = nfcGenerateBCC(bits)
    % Generate Block Check Character as per the specification of ISO/IEC
    % 14443-3, for Type A air interface. See section 6.2.3.3 in the spec
    % for details.

    % Copyright 2016-2021 The MathWorks, Inc.
    
    nBits = length(bits);
    coder.internal.errorIf((nBits ~= 32) || ~iscolumn(bits), ...
        'comm:NFC:InvalidInputSize');
    
    bcc = bits(1:8, 1);
    for k = 1:3
        currIdx = k*8 + (1:8);
        currByte = bits(currIdx, 1);
        bcc(:) = xor(bcc, currByte);
    end    
end