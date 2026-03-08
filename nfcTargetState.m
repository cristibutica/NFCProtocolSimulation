classdef nfcTargetState < uint8
    % Enum class to represent states of an NFC Target device.
    
    %   Copyright 2016 The MathWorks, Inc.
    
    % xxx: the only reason to inherit from uint8 is for codegen
    
    enumeration
        % Target States
        PowerOff (0)
        Idle (1)
        Ready (2)
        Active (3)
        Halt (4)
    end
end
