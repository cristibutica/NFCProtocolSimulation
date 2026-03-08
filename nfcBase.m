classdef (Abstract) nfcBase <  handle
    % nfcBase Base class for nfcInitiator and nfcTarget classes.

    % Copyright 2016-2018 The MathWorks, Inc.

    properties (Constant = true)
        % Fc Carrier Frequency
        Fc = 13.56e6;
        % BitRate Bit rate as a factor of Fc
        BitRate = 'Fc/128 (106 Kbps)';
    end
    properties (Access = 'public')
        % SamplesPerSymbol Samples per symbol or bit
        SamplesPerSymbol = 128;
        % Application Layer
        AppLayer
        % Enable or disable visualization
        EnableVisualization = true;
    end
    properties (Access = 'protected', Transient)
        % Bit rate factor of Fc
        pBitRateFactor = 128
        % Cascade Tag
        pCascadeTag = comm.internal.utilities.convertInt2Bit([8 8]',4);
    end
    
    methods
        function set.SamplesPerSymbol(obj, value)
            coder.internal.errorIf(mod(value, 4) ~= 0, ...
                'comm:NFC:NotFactorOf4');
            coder.internal.errorIf(value < 32, 'comm:NFC:InvalidSPS');
            obj.SamplesPerSymbol = value;
            
        end
        function seqD = getSequenceD(obj)
            % Generate sequence D
            % Manchester coding with 10% ASK
            subCarrCyclesPerSymbol = obj.pBitRateFactor / 16;
            sampsPerSubCarrCycle = obj.SamplesPerSymbol / subCarrCyclesPerSymbol;
            seqD = ones(obj.SamplesPerSymbol, 1);
            t = 0:(obj.SamplesPerSymbol/2)-1;
            seqD(1:(obj.SamplesPerSymbol/2),1) = 1 + (0.05*sin(2*pi*t/sampsPerSubCarrCycle));
        end
        function seqE = getSequenceE(obj)
            % Generate sequence E
            % Manchester coding with 10% ASK
            subCarrCyclesPerSymbol = obj.pBitRateFactor / 16;
            sampsPerSubCarrCycle = obj.SamplesPerSymbol / subCarrCyclesPerSymbol;
            seqE = ones(obj.SamplesPerSymbol, 1);
            t = 0:(obj.SamplesPerSymbol/2)-1;
            seqE(((obj.SamplesPerSymbol/2)+1) : obj.SamplesPerSymbol) = 1 + (0.05*sin(2*pi*t/sampsPerSubCarrCycle));
        end
        function seqF = getSequenceF(obj)
            % Generate sequence F
            seqF = ones(obj.SamplesPerSymbol, 1);
        end
        
    end
    methods (Static)
        function reqA = getREQA()
            % Initiator sends REQA to Target, LSB first
            reqA = [0 1 0 0 1 1 0]'; % 0x26 = REQA, MSB first
            % return as LSB first
            if (nargout == 0)
                reqA = nfcBase.convertBit2Hex([0;reqA]);
            else
                reqA = flipud(reqA); % LSB first
            end
        end
        function sel = getSEL(cascadeLevel)
            % SEL code, LSB first. When displayed, its MSB first.
            switch cascadeLevel
                case 1
                    sel = [1 0 0 1 0 0 1 1]'; % 0x93, MSB first
                case 2
                    sel = [1 0 0 1 0 1 0 1]'; % 0x95, MSB first
                case 3
                    sel = [1 0 0 1 0 1 1 1]'; % 0x97, MSB first
                otherwise
                    error(message('comm:NFC:InvalidCascadeLevel'));
            end
            if (nargout == 0)
                sel = nfcBase.convertBit2Hex(sel);
            else
                sel = flipud(sel);
            end
        end
        function hx = convertBit2Hex(bitVec)
            hxNumeric = comm.internal.utilities.convertBit2Int(bitVec, 4);
            hx = ['0x' sprintf('%x',hxNumeric')];
        end
        function hxStr = convertBit2HexStr(bitVec)
            hxNumeric = comm.internal.utilities.convertBit2Int(bitVec, 4);
            hxStr = upper(sprintf('%x',hxNumeric'));
        end
        function bitVec = convertHexStr2Bit(hexStr)
            bitVec = comm.internal.utilities.convertInt2Bit(hex2dec(hexStr(:)), 4);
        end
        function validateLENByte(LENByteIntValue, commandName)
            % Validate that the length byte is in range [3, 255]
            coder.internal.errorIf((LENByteIntValue < 3) || (LENByteIntValue > 255), ...
                'comm:NFC:InvalidLENByte', commandName);
        end
    end
end
