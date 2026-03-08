function bitVecLSBFirst = nfcByteWiseMSB2LSBFirst(bitVecMSBFirst)
    % Convert MSB first input bit vector to LSB first, byte wise i.e. one
    % byte at a time.

    % Copyright 2016-2021 The MathWorks, Inc.
    
    inLen = length(bitVecMSBFirst);
    inLenInBytes = inLen/8;
    coder.internal.errorIf(inLenInBytes ~= floor(inLenInBytes), ...
        'comm:NFC:InvalidInputLength');
    
    bitVecLSBFirst = zeros(inLen, 1, 'like', bitVecMSBFirst);
    for k = 1:inLenInBytes
        currIdx = (k-1)*8 + (1:8);
        currByte = bitVecMSBFirst(currIdx, 1);
        bitVecLSBFirst(currIdx, 1) = flipud(currByte);
    end
end