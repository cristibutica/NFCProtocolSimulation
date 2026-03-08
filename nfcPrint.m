classdef nfcPrint
    % Print with different formatting.    

    %   Copyright 2016-2017 The MathWorks, Inc.

    methods (Static)
        function Start()
            fprintf('\nStart of NFC Communication between Initiator and Target\n\n');
        end
        function End()
            fprintf('\n\nEnd of NFC Communication between Initiator and Target\n\n');
        end
        function Heading1(str)
            fprintf('\t%s\n', str);
        end
        function Heading2(str) 
            fprintf('\t\t%s\n', str);
        end
        function Heading3(str)
            fprintf('\t\t\t%s\n', str);
        end
        function Heading4(str)
            fprintf('\t\t\t\t%s\n', str);
        end
        function NewLine()
            fprintf('\n');
        end
        function CascadeLevel(varargin)
            if (nargin == 1) || (varargin{1} ~= varargin{2})
                nfcPrint.Heading2(sprintf('Cascade Level-%d', varargin{1}));
            end
        end
        function Message(str)
            fprintf('%s\n', str);
        end
    end
end
