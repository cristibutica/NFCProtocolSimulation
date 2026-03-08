classdef nfcDEP_PDU_Type
    % Enum class to represent PDU types used during Data Exchange Protocol.
    % Reference: ISO/IEC 18092, section 12.6
    
    %   Copyright 2016-2017 The MathWorks, Inc.

    enumeration
        % DEP PDU Type
        Information
        Protected
        ACK_OR_NACK
        Supervisory
    end
end