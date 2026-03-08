function [y, err] = nfcCheckCRC(x)
    % Cyclic Redundancy Control
    % Check CRC Checksum in input X as per the specification of ISO/IEC
    % 14443-3, for Type A air interface. See section 6.2.4 (CRC_A) & Annex
    % B in the spec for details. 
    % Output Y contains data without the CRC Checksum. Output ERR indicates
    % if the checksum passed or failed. 

    %   Copyright 2016-2017 The MathWorks, Inc.
    
    % Generator Polynomial
    % x^16 + x^12 + x^5 + 1
    % [1 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0 1]
    genPoly = 'x^16 + x^12 + x^5 + 1';
    % Initial Condition - 0x6363
    ic = [6 3 6 3]';
    icBin = comm.internal.utilities.convertInt2Bit(ic, 4);
    icBin = nfcByteWiseMSB2LSBFirst(icBin);
    
    crcDet = comm.CRCDetector('Polynomial', genPoly, ...
        'InitialConditions', icBin, ...
        'DirectMethod', true, ...
        'ChecksumsPerFrame', 1);
    
    [y, err] = crcDet(x);
end
