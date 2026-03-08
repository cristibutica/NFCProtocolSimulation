classdef nfcInitiatorState
    % Enum class to represent states of an NFC Initiator device.
    
    %   Copyright 2016-2017 The MathWorks, Inc.
    
    enumeration
        % Initiator States
        None
        Sent_ANTICOLLISION_Cmd
        Sent_SELECT_Cmd
        AntiCollisionLoop_Complete
    end
end