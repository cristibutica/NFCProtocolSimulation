classdef nfcTarget < nfcBase
    % nfcTarget NFC Target
    %
    % nfcTarget object represents an NFC Target that is compliant
    % with ISO/IEC 18092 Information technology - Telecommunications and
    % information exchange between systems – Near Field Communications –
    % Interface and Protocol (NFCIP-1) standard. 
    
    %   Copyright 2016-2023 The MathWorks, Inc.

    properties (Constant = true)
        % Fs Subcarrier Frequency        
        Fs = 13.56e6/16;
    end
    properties (Access = 'public')
        % UID Unique ID of Target as a string of hexadecimal numbers
        UID = '11aa22bb';
        % Received user data from Initiator
        ReceivedUserData = '';
    end
    properties (Access = 'private', Transient)
        % UID as binary vector (MSB first)
        pUID = comm.internal.utilities.convertInt2Bit(hex2dec('11AA22BB'),32);
    end
    properties (Access = 'private')
        % Target State
        pState = nfcTargetState.PowerOff;
        % DS Bit rate divisor supported for sending data. This property can
        % be a scalar or a vector with maximum 7 elements. Valid values are
        % 1, 2, 4, 8, 16, 32 and 64. The default is 1. Reference: ISO/IEC 18092,
        % section 9.1
        % 'DS' is used in the spec, so using it here instead of 'pDS'
        DS = 1;
        % DR Bit rate divisor supported for receiving data This property
        % can be a scalar or a vector with maximum 7 elements. Valid values
        % are 1, 2, 4, 8, 16, 32 and 64. The default is 1. Reference:
        % ISO/IEC 18092, section 9.1
        % 'DR' is used in the spec, so using it here instead of 'pDR'
        DR = 1;
        % Received DSi - Send-bit rate divisor supported by Initiator.
        % Reference: ISO/IEC 18092, section 12.5.1.1
        pDSi = [];
        % Received DRi - Receive-bit rate divisor supported by Initiator.
        % Reference: ISO/IEC 18092, section 12.5.1.1
        pDRi = [];
        % Received NFCID3i - Initiator's NFCID3.
        % Reference: ISO/IEC 18092, section 12.5.1.1
        pNFCID3i
        % Received DIDi. Reference: ISO/IEC 18092, section 12.5.1.1
        pDIDi
        % This Target's NFCID3. Reference: ISO/IEC 18092, section 12.5.1.2
        pNFCID3 = [];
        % Received DSI in PSL_REQ. This is the D that Initiator will use
        % for sending data i.e. this is the receiving-D for this Target.
        % Reference: ISO/IEC 18092, section 12.5.3.2
        pSelectedDSI
        % Received DRI in PSL_REQ. This is the D that Initiator will use
        % for receiving data i.e. this is the sending-D for this Target.
        % Reference: ISO/IEC 18092, section 12.5.3.2
        pSelectedDRI
        % PNI. Reference: ISO/IEC 18092, section 12.6.1.1.1
        % PNI is 2-bit long, so its range is [0,3]. This property is a
        % scalar value in that range.
        pPNI = 0;
        % Received FSD - FSD specifies maximum frame size, in bytes, that
        % Initiator/PCD could receive.
        % Reference: ISO/IEC 14443-4, section 5.1
        pFSD = [];
        % Received FSDI - FSDI is FSD Integer
        pFSDI
        % Received CID - logical address of selected Target/PICC
        % Reference: ISO/IEC 14443-4, section 5.1
        pCID
        % FSC The maximum size of a frame, in bytes, the Target/PICC can receive
        % Valid values are 16, 24, 32, 40, 48, 64, 96, 128, 256.
        % The default value, as per the spec, is 32 bytes but support the
        % maximum (256) only for now.
        % Reference: ISO/IEC 14443-4, section 5.2.3. 
        FSC = 256;
        % FSCI, derived from FSC
        % For FSC=256, FSCI=8
        pFSCI = 8;
        % SameDinEachDirection Does Target/PICC support same or different
        % bit rates in each direction (Initiator/PCD-to-Target/PICC and
        % Target/PICC-to-Initiator/PCD). Boolean scalar value. True
        % indicates bit rates must be same in each direction. False
        % indicates different bit rates supported. Default
        % is true.
        % Reference: ISO/IEC 14443-4, section 5.2.4.
        SameDinEachDirection = true;
        % Block number. Toggles between 0 and 1, so stored as logical.
        % Reference: ISO/IEC 14443-4, section 7
        pBlockNumber = true;
        % Time Scope to visualize Manchester coded 10% ASK modulation
        pTS
        % Spectrum Analyzer to visualize load modulation spectrum
        pSA
    end
    methods
        function obj = nfcTarget(varargin)
            coder.internal.errorIf(mod(nargin,2) ~= 0, ...
                'comm:NFC:InvalidPVPairs');
            for i = 1:2:nargin
                obj.(varargin{i}) = varargin{i+1};
            end
            if obj.EnableVisualization
                % Initialize TimeScope
                % 18 symbols in ATQA, so TimeSpan of 20 symbols
                obj.pTS = timescope('Name', 'Manchester - 10% ASK', ...
                    'Title', 'ATQA Command by Target', ...
                    'SampleRate',  (obj.Fc * obj.SamplesPerSymbol)/obj.pBitRateFactor, ...
                    'TimeSpanSource','property', ...
                    'TimeSpan', 20/(obj.Fc /obj.pBitRateFactor), ...
                    'YLimits', [0 1.2], ...
                    'AxesScaling', 'manual', ...
                    'Position', figposition([10, 50, 30, 30]));
                % Initialize SpectrumAnalyzer
                obj.pSA = spectrumAnalyzer('Name', 'Load Modulation', ...
                    'Title', 'Target Signal Spectrum', ...
                    'SampleRate', (obj.Fc * obj.SamplesPerSymbol)/obj.pBitRateFactor, ...
                    'Position', figposition([10, 10, 30, 30]));
            end
        end
        function disp(obj)
            s = struct('Fc', obj.Fc, ...
                'Fs', obj.Fs, ...
                'SamplesPerSymbol', obj.SamplesPerSymbol, ...
                'UID', obj.UID, ...
                'AppLayer', obj.AppLayer, ...
                'ReceivedUserData', obj.ReceivedUserData, ...
                'EnableVisualization', obj.EnableVisualization);
            disp(s);
        end
        function set.UID(obj, value)
            value = convertStringsToChars(value);
            validateattributes(value, {'char'}, {'vector'}, '', 'UID');
            len = length(value);
            % Only single and double UID are currently supported. Triple UID
            % is not yet supported.
            coder.internal.errorIf(~any(len == [8,14]), 'comm:NFC:InvalidUIDValue1');
            if (len == 8)
                % Single UID
                coder.internal.errorIf(isequal(value(1:2),'88'), ...
                    'comm:NFC:InvalidUIDValue2', 'UID0');                
            elseif (len == 14)
                % Double UID
                coder.internal.errorIf(isequal(value(7:8),'88'), ...
                    'comm:NFC:InvalidUIDValue2', 'UID3');
                % No such constraint for Triple UID
            end
            uidBin = zeros(4*len, 1);
            for k=1:len
                try
                    d = hex2dec(value(k));
                catch me
                    if contains(me.identifier, 'InvalidCharacters')
                        error(message('comm:NFC:InvalidUIDFormat'));
                    else
                        rethrow(me);
                    end
                end
                uidBin((k-1)*4 + (1:4), 1) = comm.internal.utilities.convertInt2Bit(d, 4);
            end
            obj.pUID = uidBin; %#ok<*MCSUP>
            obj.UID = value;
        end
        function atqA = getATQA(obj)
            % ATQA - 16 bits, MSB first. See Table 4 of ISO/IEC 14443-3
            % b8b7 are based on UID size; b5=1
            switch length(obj.pUID)
                case 32
                    % 4 bytes - UID size = single
                    b8b7 = [0 0] ;
                case 56
                    % 7 bytes - UID size = double
                    b8b7 = [0 1];
                case 80
                    b8b7 = [1 0];
                    % 10 bytes - UID size = triple
                otherwise
                    error(message('comm:NFC:InvalidUID'));
            end
            atqA = [0 0 0 0 0 0 0 0 b8b7 0 1 0 0 0 0]';
            % return as LSB first
            atqA = flipud(atqA);
        end
        function uidBitVec = getUIDBitVector(obj)
            uidBitVec = obj.pUID;
        end
        function setDSi(obj, dsi)
            % dsi must be 8 bits long (BSi byte of ATR_REQ)
            dsiVec = [64, 32, 16, 8]';
            dsiToSet = dsiVec(logical(dsi(5:8,1)));
            obj.pDSi(end + (1:length(dsiToSet))) = dsiToSet;
        end
        function setDRi(obj, dri)
            % dsi must be 8 bits long (BRi byte of ATR_REQ)
            driVec = [64, 32, 16, 8]';
            driToSet = driVec(logical(dri(5:8,1)));
            obj.pDRi(end + (1:length(driToSet))) = driToSet;
        end
        function setNFCID3i(obj, value)
            coder.internal.errorIf(length(value) ~= 80, ...
                'comm:NFC:InvalidNFCID3', 'NFCID3i');
            obj.pNFCID3i = value;
        end
        function [nfcid3, obj] = getNFCID3(obj)
            if isempty(obj.pNFCID3)
                obj.pNFCID3 = generateNFCID3();
            end
            nfcid3 = obj.pNFCID3;
        end
        function setDIDi(obj, DIDi)
            obj.pDIDi = DIDi;
        end
        function DIDi = getDIDi(obj)
            DIDi = obj.pDIDi;
        end
        function dst = getDSt(obj)
            % returned dst is MSB first. Reference: ISO/IEC 18092, section
            % 12.5.1.2.1
            ds = obj.DS;
            dst = zeros(4,1);
            dst(1,1) = any(ds == 64);
            dst(2,1) = any(ds == 32);
            dst(3,1) = any(ds == 16);
            dst(4,1) = any(ds == 8);
        end
        function drt = getDRt(obj)
            % returned drt is MSB first. Reference: ISO/IEC 18092, section
            % 12.5.1.2.1
            dr = obj.DR;
            drt = zeros(4,1);
            drt(1,1) = any(dr == 64);
            drt(2,1) = any(dr == 32);
            drt(3,1) = any(dr == 16);
            drt(4,1) = any(dr == 8);
        end
        function setSelectedDSI(obj, value)
            obj.pSelectedDSI = value;
        end
        function setSelectedDRI(obj, value)
            obj.pSelectedDRI = value;
        end
        function appendUserData(obj, userData)
            userDataLen = length(userData);
            obj.ReceivedUserData(end + (1:userDataLen)) = userData;
        end
        function pni = getPNI(obj)
            % return PNI as a 2-bit column vector, MSB first
            pni = comm.internal.utilities.convertInt2Bit(obj.pPNI, 2);
        end
        function incrementPNI(obj)
            % Increment current PNI. Range of PNI is [0,3].
            if (obj.pPNI == 3)
                obj.pPNI = 0;
            else
                obj.pPNI = obj.pPNI + 1;
            end
        end
        function resetPNI(obj)
            obj.pPNI = 0;
        end
        function state = getState(obj)
            state = obj.pState;
        end
        function setFSDI(obj, fsdi)
            
            % fsdi is 4-element bit vector, MSB first
            fsdiInt = comm.internal.utilities.convertBit2Int(fsdi, 4);
            
            % An Initiator/PCD setting FSDI = '9'-'F' is not compliant with this
            % standard. A received value of FSDI = '9'-'F' should be
            % interpreted by the Target/PICC as FSDI = '8' (FSD = 256 bytes).
            % Reference: ISO/IEC 14443-4, section 5.1
            
            % See Table 1 in ISO/IEC 14443-4 (section 5.1) for FSDI to FSD
            % conversion
            % FSD is in bytes
            switch fsdiInt
                case 0
                    fsd = 16;
                case 1
                    fsd = 24;
                case 2
                    fsd = 32;
                case 3
                    fsd = 40;
                case 4
                    fsd = 48;
                case 5
                    fsd = 64;
                case 6
                    fsd = 96;
                case 7
                    fsd = 128;
                case 8
                    fsd = 256;
                otherwise
                    fsdiInt = 8;
                    fsd = 256;
            end                    
            obj.pFSDI = fsdiInt;
            obj.pFSD = fsd;            
        end
        function obj = setCID(obj, cid)
            % CID is MSB-first 4-element long bit vector.
            % Reference: ISO/IEC 14443-4, section 5.1
            obj.pCID = cid;
        end
        function toggleBlockNumber(obj)
            obj.pBlockNumber = ~obj.pBlockNumber;
        end

        % --- Protocol Methods ---%
        
        function ATQA_StandardFrame = receiveREQA(obj, reqAShortFrame)
            % Target receives REQA (REQuest command, Type A) from
            % Initiator and responds with ATQA (Answer To Request).
            % Reference: ISO/IEC 14443-3, section 6.5.2
            
            % Target receives REQA from Initiator and validates it
            obj.pState = nfcTargetState.Idle;
            receivedREQA = demodulate(obj, reqAShortFrame);
            
            if isempty(receivedREQA)
                ATQA_StandardFrame = [];
                return
            end
            
            reqACode = obj.getREQA(); % REQA, LSB first            
            isREQAValid = isequal(receivedREQA, reqACode);
            coder.internal.errorIf(~isREQAValid, 'comm:NFC:REQAFailed');
            
            nfcPrint.Heading1('Target received REQA');
            
            % Target responds with ATQA
            % LSB first
            atqACode = getATQA(obj);
            atqACodeWithParityBits = nfcAddOddParityBits(atqACode);
            ATQA_StandardFrame = modulate(obj, atqACodeWithParityBits);

            obj.pState = nfcTargetState.Ready;
            if obj.EnableVisualization
                % Visualize ATQA to illustrate Manchester coded 10% ASK
                % modulation
                obj.pTS(ATQA_StandardFrame);
                release(obj.pTS);
            end
            nfcPrint.Heading2('Target transmitted ATQA in response to REQA');
        end
        function targetACFrame = antiCollisionLoop(obj, initiatorACFrame)
            
            targetACFrame = [];
            
            [recSEL, recNVB, recData] = receiveAC(obj, initiatorACFrame);
            % note that recSEL, recNVB & recData are LSB first
            
            if isempty(recSEL)                
                return;
            end
            
            % Target creates the data to be sent to Initiator
            recNVBmsbFirst = flipud(recNVB); % convert to MSB first
            uid = getUIDBitVector(obj);
            uidLen = length(uid);
            recNVBInt = comm.internal.utilities.convertBit2Int(recNVBmsbFirst,4);
            nBits = recNVBInt(1)*8 + recNVBInt(2);
            
            % Determine cascade level
            if all(recSEL == obj.getSEL(1))
                % cascade level - 1 (0x93)
                
                nfcPrint.Heading3('Target received Cascade Level-1 SEL code');
                % check NVB
                if (nBits == 16)
                    % transmit 4 bytes of UID
                    
                    switch uidLen
                        case 32
                            % Single UID                            
                            uidTmp = uid;
                            msg = 'Target transmitted full UID';
                            
                        case 56
                            % Double UID                            
                            uidTmp = [obj.pCascadeTag; uid(1:24,1)];
                            msg = 'Target transmitted CL1 UID';
                            
                        case 80
                            % Triple UID - not yet supported
                            coder.internal.error('comm:NFC:InvalidUIDValue1');
                    end

                    uidTmp1 = nfcByteWiseMSB2LSBFirst(uidTmp);
                    bcc = nfcGenerateBCC(uidTmp1);
                    targetACCmd1 = [uidTmp1; bcc];
                    targetACCmd1WithParityBits = nfcAddOddParityBits(targetACCmd1);
                    targetACFrame = modulate(obj, targetACCmd1WithParityBits);
                    if obj.EnableVisualization
                        % Visualize spectrum to illustrate load modulation
                        obj.pSA(targetACFrame);
                        release(obj.pSA);
                    end
                    
                    nfcPrint.Heading4(msg);
                    
                elseif (nBits == 56)
                    % Complete Initiator msg for this cascade level received. Check if
                    % received UID matches this Target's UID.
                    
                    % CRC & BCC checks are common for all UID types - perform them first
                    [recData1, err] = nfcCheckCRC([recSEL; recNVB; recData]);
                    coder.internal.errorIf(err ~= 0, ...
                        'comm:NFC:CRCFailedCL', 1);
                    recData1 = nfcByteWiseMSB2LSBFirst(recData1);
                    recData2 = recData1(17:48, 1);
                    recBCC = recData1(49:56, 1);
                    expBCC = nfcGenerateBCC(recData2);
                    coder.internal.errorIf(~isequal(recBCC, expBCC), ...
                        'comm:NFC:BCCCheckFailedCL', 1);
                    
                    if (uidLen == 32)
                        % Single UID
                        
                        % The data in recData2 is all UID. Check that it matches
                        % this Target's UID.
                        if isequal(uid, recData2)
                            % received UID matches this Target's UID. Send back SAK
                            
                            obj.pState = nfcTargetState.Active;
                            
                            nfcPrint.Heading4('Target selection confirmed');
                            
                            b3 = 0; % cascade bit unset/clear - UID complete
                            msg = 'Target transmitted SAK with UID complete flag';                          
                        else
                            % received UID does NOT match this Target's UID. 
                            coder.internal.error('comm:NFC:InvalidRxUID');
                        end
                        
                    elseif (uidLen == 56)
                        % Double UID
                        
                        if isequal(recData2(9:32), uid(1:24))
                            % received UIDCL1 matches this Target's UIDCL1. Send back SAK

                            b3 = 1; % cascade bit set - UID not complete
                            msg = 'Target transmitted SAK with UID not complete flag';
                        else
                            % received UID does NOT match this Target's UID. 
                            coder.internal.error('comm:NFC:InvalidRxUID');
                        end
                    else
                        % Triple UID. Not supported yet.
                        coder.internal.error('comm:NFC:InvalidUIDValue1');
                    end
                    
                    b7 = 1; % Target is compliant with NFCIP-1 transport protocol
                    SAK = [0 b7 0 0 0 b3 0 0]'; % MSB first
                    SAKwithCRC = nfcAddCRC(nfcByteWiseMSB2LSBFirst(SAK));
                    SAKStdFrame = nfcAddOddParityBits(SAKwithCRC);
                    targetACFrame = modulate(obj, SAKStdFrame);
                    
                    nfcPrint.Heading4(msg);
                    
                elseif (nBits > 16)
                    % This indicates there was a collision in data received by Initiator
                    % (sent by multiple Targets). Check the UID sent back by Initiator &
                    % determine if this Target is selected or not.
                    recDataLen = length(recData);
                    uidTmp = nfcByteWiseMSB2LSBFirst(uid);
                    isThisTargetSelected = isequal(recData, uidTmp(1:recDataLen, 1));
                    if isThisTargetSelected
                        % send remaining bits of UID
                        bcc = nfcGenerateBCC(uidTmp);
                        
                        nBitsToTx = uidLen - recDataLen;
                        bitsToTx = [uidTmp((recDataLen+1):uidLen, 1); bcc];
                        
                        nSplitBits = mod(nBitsToTx, 8);
                        if (nSplitBits == 0)
                            
                            bitsToTxStdFrame = nfcAddOddParityBits(bitsToTx);
                            targetACFrame = modulate(obj, bitsToTxStdFrame);
                            
                        else
                            
                            % The parity bit for bits in split byte is ignored -
                            % just use 1 as parity bit
                            splitByteWithParityBit = [bitsToTx(1:nSplitBits,1); 1];
                            % +8 for BCC
                            remBits = bitsToTx((nSplitBits+1) : (nBitsToTx+8), 1);
                            remBitsWithParityBits = nfcAddOddParityBits(remBits);
                            targetACCmd1WithParityBits = [splitByteWithParityBit; remBitsWithParityBits];
                            targetACFrame = modulate(obj, targetACCmd1WithParityBits);
                            
                        end
                        
                    else
                        % go to IDLE state. Do nothing here for now.
                    end % if isThisTargetSelected
                    
                else
                    coder.internal.error('comm:NFC:InvalidSELNVB');
                    
                end
                
            elseif all(recSEL == obj.getSEL(2))
                % cascade level - 2 (0x95)
                
                nfcPrint.Heading3('Target received Cascade Level-2 SEL code');
                if (nBits == 16)
                    % transmit 4 bytes of UID
                    
                    switch uidLen
                        case 56
                            % Double UID
                            
                            uidTmp = nfcByteWiseMSB2LSBFirst(uid(25:56));
                            bcc = nfcGenerateBCC(uidTmp);
                            targetACCmd1 = [uidTmp; bcc];
                            targetACCmd1WithParityBits = nfcAddOddParityBits(targetACCmd1);
                            targetACFrame = modulate(obj, targetACCmd1WithParityBits);
                            
                            nfcPrint.Heading4('Target transmitted CL2 UID');
                        case 80
                            % Triple UID - not yet supported
                            coder.internal.error('comm:NFC:InvalidUIDValue1');

                    end
                elseif (nBits == 56)
                    % Complete Initiator msg for this cascade level received. Check if
                    % received UID matches this Target's UID.
                    
                    % CRC & BCC checks are common for all UID types - perform them first
                    [recData1, err] = nfcCheckCRC([recSEL; recNVB; recData]);
                    coder.internal.errorIf(err ~= 0, ...
                        'comm:NFC:CRCFailedCL', 1);
                    recData1 = nfcByteWiseMSB2LSBFirst(recData1);
                    recData2 = recData1(17:48, 1);
                    recBCC = recData1(49:56, 1);
                    expBCC = nfcGenerateBCC(recData2);
                    coder.internal.errorIf(~isequal(recBCC, expBCC), ...
                        'comm:NFC:BCCCheckFailedCL', 1);

                    if (uidLen == 56)
                        % Double UID
                        
                        if isequal(uid(25:56), recData2)
                            % received UIDCL2 matches this Target's UIDCL2. Send back SAK
                            
                            obj.pState = nfcTargetState.Active;
                            
                            nfcPrint.Heading4('Target selection confirmed');
                            
                            b3 = 0; % cascade bit unset/clear - UID complete
                            b7 = 1; % Target is compliant with NFCIP-1 transport protocol
                            SAK = [0 b7 0 0 0 b3 0 0]'; % MSB first
                            SAKwithCRC = nfcAddCRC(nfcByteWiseMSB2LSBFirst(SAK));
                            SAKStdFrame = nfcAddOddParityBits(SAKwithCRC);
                            targetACFrame = modulate(obj, SAKStdFrame);
                            
                            nfcPrint.Heading4('Target transmitted SAK with UID complete flag');
                        else
                            % received UID does NOT match this Target's UID.
                            coder.internal.error('comm:NFC:InvalidRxUID');
                        end
                        
                    else
                        % Triple UID not yet supported
                        coder.internal.error('comm:NFC:InvalidUIDValue1');

                    end
                    
                elseif (nBits > 16)
                    % This indicates there was a collision in data received by Initiator
                    % (sent by multiple Targets). Check the UID sent back by Initiator &
                    % determine if this Target is selected or not.
                end
                
            else
                % cascade level - 3 (0x97) - not yet supported.
                coder.internal.error('comm:NFC:UnsupportedCascadeLevel');
            end
            
        end
        function [sel, nvb, data] = receiveAC(obj, initiatorACFrame)
            % Target receives anticollision & select commands from
            % Initiator
            
            sel = []; %#ok<*NASGU>
            nvb = [];
            data = [];
            
            acCmd1 = demodulate(obj, initiatorACFrame);
            if isempty(acCmd1)
                return
            end
            
            % Bit Oriented Anticollision Frame could have a SPLIT BYTE - handle it
            acCmd1Len = length(acCmd1);
            if (mod(acCmd1Len, 9) == 0)
                % Full Byte
                [isParityValid1, acCmd2] = nfcCheckOddParityBits(acCmd1);
                coder.internal.errorIf(~isParityValid1, ...
                    'comm:NFC:OddParityCheckFailedACT', 'FULL BYTE');
                coder.internal.errorIf(length(acCmd2) < 16, ...
                    'comm:NFC:InvalidACCmd');
            else
                % Split Byte
                nFullBytes = floor(acCmd1Len/9);
                nRemBits = acCmd1Len - (nFullBytes * 9);
                [isParityValid2, acCmd3] = nfcCheckOddParityBits(acCmd1(1:(nFullBytes*9)));
                coder.internal.errorIf(~isParityValid2, ...
                    'comm:NFC:OddParityCheckFailedACT', 'SPLIT BYTE');
                acCmd2 = [acCmd3; acCmd1((nFullBytes*9) + (1:nRemBits), 1)];
            end
            
            sel = acCmd2(1:8,1);
            nvb = acCmd2(9:16,1);
            lenACCmd2 = length(acCmd2);
            if ( lenACCmd2 > 16)
                data = acCmd2(17:lenACCmd2, 1);
            end
            
        end
        function targetATR_RESFrame = receiveATR_REQ(obj, initiatorATR_REQFrame)
            % Target receives ATR_REQ (Attribute Request) from Initiator
            % and responds with ATR_RES (Attribute Request Response).
            % Reference: ISO/IEC 18092, section 12.5.1.2
            
            recATR_REQbits = demodulate(obj, initiatorATR_REQFrame);

            [isParityValid, recATR_REQSbits1] = nfcCheckOddParityBits(recATR_REQbits);
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'ATR_REQ');
            
            [recATR_REQSbits2, err] = nfcCheckCRC(recATR_REQSbits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'ATR_REQ');
            recATR_REQSbits3 = nfcByteWiseMSB2LSBFirst(recATR_REQSbits2);
            
            nfcPrint.Heading2('Target received ATR_REQ');
            
            % Decode ATR_REQ
            
            % First byte is the Start Byte which is 0xF0.
            recDataLen = length(recATR_REQSbits3);
            recLengthByte = recATR_REQSbits3(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'ATR_REQ');
            recCMD1 = recATR_REQSbits3(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 4]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'ATR_REQ', 'xD4');
            % CMD2 must be 0 - skip checking it
            recCMD2 = recATR_REQSbits3(25:32, 1); 
            recNFCID3i = recATR_REQSbits3(33:112, 1); % 10 bytes = 80 bits
            setNFCID3i(obj, recNFCID3i);
            recDIDi = recATR_REQSbits3(113:120, 1);
            coder.internal.errorIf(~isequal(recDIDi, [0 0 0 0 0 0 0 0]'), 'comm:NFC:MultipleTargetsNotSupported');
            setDIDi(obj, recDIDi);
            recBSi = recATR_REQSbits3(121:128, 1);
            setDSi(obj, recBSi);
            recBRi = recATR_REQSbits3(129:136, 1);
            setDRi(obj, recBRi);
            recPPi = recATR_REQSbits3(137:144, 1); 
            
            % Respond with ATR_RES. Reference: ISO/IEC 18092, section 12.5.1.2
            
            CMD1 = [1 1 0 1 0 1 0 1]'; % xD5; MSB-first
            CMD2 = [0 0 0 0 0 0 0 1]'; % x01; MSB first
            NFCID3t = getNFCID3(obj);
            DIDt = getDIDi(obj);
            BSt = [0; 0; 0; 0; getDSt(obj)];
            BRt = [0; 0; 0; 0; getDRt(obj)];
            WT = comm.internal.utilities.convertInt2Bit(14,4); % Default value of 14
            TO = [0; 0; 0; 0; WT];
            % Length Reduction value - set it to up to Byte 64 valid in Transport
            % Data.
            LRt = [0 0]';
            % General bytes are not used
            Gt = 0;
            % Target does not use NAD
            NAD = 0;
            PPt = [0; 0; LRt; 0; 0; Gt; NAD];
            transportDataField = [CMD1; CMD2; NFCID3t; DIDt; BSt; BRt; TO; PPt];
            startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
            lengthByteInt = (length(transportDataField)/8) + 1;
            obj.validateLENByte(lengthByteInt, 'ATR_RES');
            lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
            atrRes = [startByte; lengthByte; transportDataField];
            atrResFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(atrRes));
            atrResStdFrame = nfcAddOddParityBits(atrResFrame);
            targetATR_RESFrame = modulate(obj, atrResStdFrame);
            
            nfcPrint.Heading3('Target transmitted ATR_RES in response to ATR_REQ');
        end
        function targetPSL_RESFrame = receivePSL_REQ(obj, initiatorPSL_REQFrame)
            % Target receives PSL_REQ (Parameter Selection Request) from Target &
            % responds with PSL_RES (Parameter Selection Response)
            % Reference: ISO/IEC 18092, section 12.5.3.1 (PSL_REQ) & 12.5.3.2 (PSL_RES)
            
            recPSL_REQbits = demodulate(obj, initiatorPSL_REQFrame);
            
            [isParityValid, recPSL_REQbits1] = nfcCheckOddParityBits(recPSL_REQbits);
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'PSL_REQ');

            [recPSL_REQbits2, err] = nfcCheckCRC(recPSL_REQbits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'PSL_REQ');
            recPSL_REQbits3 = nfcByteWiseMSB2LSBFirst(recPSL_REQbits2);
            
            nfcPrint.Heading2('Target received PSL_REQ');
            
            % Decode PSL_REQ
            
            % First byte is the Start Byte which is 0xF0.
            recDataLen = length(recPSL_REQbits3);
            recLengthByte = recPSL_REQbits3(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'PSL_REQ');
            recCMD1 = recPSL_REQbits3(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 4]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'PSL_REQ', 'xD4');
            recCMD2 = recPSL_REQbits3(25:32, 1); 
            recDID = recPSL_REQbits3(33:40, 1);
            coder.internal.errorIf(~isequal(recDID, [0 0 0 0 0 0 0 0]'), 'comm:NFC:MultipleTargetsNotSupported');
            coder.internal.errorIf(~isequal(recDID, getDIDi(obj)), 'comm:NFC:InvalidRxDIDt');
            recBRS = recPSL_REQbits3(41:48, 1);
            recDSI = recBRS(3:5, 1);
            dsi = 2^comm.internal.utilities.convertBit2Int(recDSI, 3);
            setSelectedDSI(obj, dsi);
            recDRI = recBRS(6:8, 1);
            dri = 2^comm.internal.utilities.convertBit2Int(recDRI, 3);
            setSelectedDRI(obj, dri);
            recFRS = recPSL_REQbits3(49:56, 1); 
            
            % Send back PSL_RES (Parameter Selection Response)
            % Reference: ISO/IEC 18092, section 12.5.3.2
            
            CMD1 = [1 1 0 1 0 1 0 1]'; % xD5; MSB-first
            CMD2 = [0 0 0 0 0 1 0 1]'; % x05; MSB first
            DID = getDIDi(obj);
            transportDataField = [CMD1; CMD2; DID];
            startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
            lengthByteInt = (length(transportDataField)/8) + 1;
            obj.validateLENByte(lengthByteInt, 'PSL_RES');
            lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
            pslRes = [startByte; lengthByte; transportDataField];
            pslResFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(pslRes));
            pslResStdFrame = nfcAddOddParityBits(pslResFrame);
            targetPSL_RESFrame = modulate(obj, pslResStdFrame);
            
            nfcPrint.Heading3('Target transmitted PSL_RES in response to PSL_REQ');
        end
        function targetDEP_RESFrame = receiveInformationPDU(obj, initiatorDEP_REQFrame)
            % Target receives Information PDU (Protocol Data Unit) of DEP
            % (Data Exchange Protocol) from Initiator as DEP_REQ (DEP Request)
            % and responds with an ACK PDU in DEP_RES (DEP Response).
            % Reference: ISO/IEC 18092, section 12.6
            
            recDEP_REQbits = demodulate(obj, initiatorDEP_REQFrame);

            [isParityValid, recDEP_REQbits1] = nfcCheckOddParityBits(recDEP_REQbits);
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'DEP_REQ');
            
            [recDEP_REQbits2, err] = nfcCheckCRC(recDEP_REQbits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'DEP_REQ');
            recDEP_REQbits3 = nfcByteWiseMSB2LSBFirst(recDEP_REQbits2);
            
            % Decode DEP_REQ
            
            % First byte is the Start Byte which is 0xF0.
            recDataLen = length(recDEP_REQbits3);
            recLengthByte = recDEP_REQbits3(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'DEP_REQ');
            recCMD1 = recDEP_REQbits3(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 4]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'DEP_REQ', 'xD4');
            % CMD2 must be x06
            recCMD2 = recDEP_REQbits3(25:32, 1);
            recCMD2int = comm.internal.utilities.convertBit2Int(recCMD2, 4);
            coder.internal.errorIf(~isequal(recCMD2int, [0, 6]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD2', 'DEP_REQ', 'x06');
            recPFB = recDEP_REQbits3(33:40, 1);
            % first 3 bits of recPFB must be [0 0 0] for information PDU
            coder.internal.errorIf(~isequal(recPFB(1:3,1), [0 0 0]'), ...
                'comm:NFC:NotInfoPDU');
            
            nfcPrint.Heading2('Target received an Information PDU in DEP_REQ');
            
            recMI = recPFB(4, 1);
            recPNI = recPFB(7:8, 1);
            recUserData = recDEP_REQbits3(41:end, 1);
            recUserDataBytes = comm.internal.utilities.convertBit2Int(recUserData, 8);
            appendUserData(obj, char(recUserDataBytes'));
            
            % Respond with DEP_RES. Reference: ISO/IEC 18092, section 12.6
            if (recMI == 1)
                % chaining activated. Respond with a ACK/NACK pdu
                % Reference: ISO/IEC 18092, section 12.6.1.3.3
                coder.internal.errorIf(true, 'comm:NFC:MIChainingNotSupported');
            else
                % chaining NOT activated. Respond with a Information pdu
                % Reference: ISO/IEC 18092, section 12.6.1.3.3
                
                nfcPrint.Heading3('MI chaining not activated in received information PDU');
                CMD1 = comm.internal.utilities.convertInt2Bit([13, 5]', 4); % xD5; MSB-first
                CMD2 = comm.internal.utilities.convertInt2Bit([0, 7]', 4); % x07; MSB first; DEP_RES
                % Information PDU
                MI = 0; % MI chaining not activated
                NAD = 0; % NAD not available
                DID = 0; % DID not available
                PNI = getPNI(obj);
                % Target PNI must be same as the received PNI
                coder.internal.errorIf(~isequal(PNI, recPNI), 'comm:NFC:InvalidPNIInfoPDU');
                nfcPrint.Heading3(sprintf('Received Initiator PNI: %d', ...
                    comm.internal.utilities.convertBit2Int(recPNI,2)));
                nfcPrint.Heading3(sprintf('Target PNI: %d', comm.internal.utilities.convertBit2Int(PNI,2)));
                PFB = [0; 0; 0; MI; NAD; DID; PNI]; % 8-bits
                DEPHeader = [CMD1; CMD2; PFB];
                transportDataField = DEPHeader; % No user data
                startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
                lengthByteInt = (length(transportDataField)/8) + 1;
                obj.validateLENByte(lengthByteInt, 'DEP_RES');
                lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
                depRes = [startByte; lengthByte; transportDataField];
                depResFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(depRes));
                depResStdFrame = nfcAddOddParityBits(depResFrame);
                targetDEP_RESFrame = modulate(obj, depResStdFrame);
                nfcPrint.Heading3(['Target transmitted an Information PDU in DEP_RES ' ...
                    'in response to DEP_REQ']);
                % Increment Target's PNI
                incrementPNI(obj);
                
            end
        end
        function targetRLS_RESFrame = receiveRLS_REQ(obj, initiatorRLS_REQFrame)
            % Target receives RLS_REQ (Release request) from Initiator and
            % responds with RSL_RES (Release response).
            % Reference: ISO/IEC 18092, section 12.7.2
            
            recRLS_REQbits = demodulate(obj, initiatorRLS_REQFrame);
            
            [isParityValid, recRLS_REQbits1] = nfcCheckOddParityBits(recRLS_REQbits);
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'RLS_REQ');

            [recRLS_REQbits2, err] = nfcCheckCRC(recRLS_REQbits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'RLS_REQ');
            recRLS_REQbits3 = nfcByteWiseMSB2LSBFirst(recRLS_REQbits2);
            
            % Decode RLS_REQ
            
            % First byte is the Start Byte which is 0xF0.
            recDataLen = length(recRLS_REQbits3);
            recLengthByte = recRLS_REQbits3(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'RLS_REQ');
            recCMD1 = recRLS_REQbits3(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 4]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'RLS_REQ', 'xD4');
            % CMD2 must be x0A
            recCMD2 = recRLS_REQbits3(25:32, 1);
            recCMD2int = comm.internal.utilities.convertBit2Int(recCMD2, 4);
            coder.internal.errorIf(~isequal(recCMD2int, [0, 10]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD2', 'RLS_REQ', 'x0A');
            % DID is optional in RLS_REQ. As DID is not used, skip it.
            
            nfcPrint.Heading2('Target received RLS_REQ');
            
            % Respond with RLS_RES. Reference: ISO/IEC 18092, section 12.7.2
            
            CMD1 = comm.internal.utilities.convertInt2Bit([13, 5]', 4); % xD5; MSB-first
            CMD2 = comm.internal.utilities.convertInt2Bit([0, 11]', 4); % x0B; MSB first; DEP_RES
            % DID is optional in RLS_RES. As DID is not used, do not send it.
            transportDataField = [CMD1; CMD2];
            startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
            lengthByteInt = (length(transportDataField)/8) + 1;
            obj.validateLENByte(lengthByteInt, 'RLS_REQ');
            lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
            rlsRes = [startByte; lengthByte; transportDataField];
            rlsResFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(rlsRes));
            rlsResStdFrame = nfcAddOddParityBits(rlsResFrame);
            targetRLS_RESFrame = modulate(obj, rlsResStdFrame);
            
            nfcPrint.Heading3('Target transmitted RLS_RES in response to RLS_REQ');
        end
        function [targetATSFrame] = receiveRATS(obj, initiatorRATSFrame)
            % Target/PICC receives RATS from Initiator/PCD and responds with ATS
            % Reference: ISO/IEC 14443-4, section 5
            
            recRATSbits = demodulate(obj, initiatorRATSFrame);
            
            [isParityValid, recRATSbits1] = nfcCheckOddParityBits(recRATSbits);
            
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'RATS');            
            coder.internal.errorIf(length(recRATSbits1) ~= 32, ...
                'comm:NFC:InvalidRATS');
            
            [recRATSbits2, err] = nfcCheckCRC(recRATSbits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'RATS');
            recRATSbits3 = nfcByteWiseMSB2LSBFirst(recRATSbits2);
            
            % Decode RATS
            
            % First byte is the Start Byte which is 0xE0.
            recFSDI = recRATSbits3(9:12, 1);
            recCID = recRATSbits3(13:16, 1);
            setFSDI(obj, recFSDI);
            setCID(obj, recCID);
            
            nfcPrint.Heading2('Target received RATS');
            
            % Respond with ATS. Reference: ISO/IEC 14443-4, section 5.2
            %
            % T0 - Format byte. Reference: ISO/IEC 14443-4, section 5.2.3
            % b8 must be 0
            b8 = 0;
            b72b5 = [1 1 1]'; % TC, TB, TA transmitted
            % b4-b1 = FSCI;
            % FSC defines the maximum size of a frame, in bytes, accepted by Target/PICC.
            % FSCI is FSC integer. See spec for FSCI-to-FSC mapping.
            b42b1 = comm.internal.utilities.convertInt2Bit(obj.pFSCI, 4);
            formatByte = [b8; b72b5; b42b1]; % MSB first
            numFormatByte = 1;
            
            % Interface byte TA. Reference: ISO/IEC 14443-4, section 5.2.4
            % b8 - Same or different D supported in each directions
            b8 = obj.SameDinEachDirection;
            % DS=8,4,2 not supported from Target/PICC to Initiator/PCD; 
            % default specified in standard
            b7tob5 = [0 0 0]'; 
            ds = obj.DS;
            b7tob5(1) = double(any(ds==8));
            b7tob5(2) = double(any(ds==4));
            b7tob5(3) = double(any(ds==2));
            b4 = 0;
            b3tob1 = [0 0 0]'; % DR=8,4,2 not supported from Initiator/PCD to Target/PICC;
            % default specified in standard
            dr = obj.DR;
            b3tob1(1) = double(any(dr==8));
            b3tob1(2) = double(any(dr==4));
            b3tob1(3) = double(any(dr==2));
            
            TA = [b8; b7tob5; b4; b3tob1]; % MSB first
            numTAByte = 1;
            
            % Interface byte TB. Reference: ISO/IEC 14443-4, section 5.2.5
            FWI = [0 1 0 0]'; % 4. default specified in standard
            SFGI = [0 0 0 0]'; % 0. default specified in standard
            TB = [FWI; SFGI]; % MSB first
            numTBByte = 1;
            
            % Interface byte TC. Reference: ISO/IEC 14443-4, section 5.2.6
            b8tob3 = [0 0 0 0 0 0]';
            b2 = 1; % CID supported. default specified in standard
            b1 = 0; % NAD not supported. default specified in standard
            TC = [b8tob3; b2; b1]; % MSB first
            numTCByte = 1;
            
            % Historical bytes not supported/transmitted. They are optional, as per
            % the spec. Reference: ISO/IEC 14443-4, section 5.2.7
            numHistoricalBytes = 0;
            
            % TL - Length byte. Reference: ISO/IEC 14443-4, section 5.2.2
            % +1, for itself (TL byte). 2 CRC bytes are not included in TL
            TLint = numFormatByte + numTAByte + numTBByte + numTCByte + numHistoricalBytes + 1;
            coder.internal.errorIf(TLint > (obj.pFSD-2), ...
                'comm:NFC:InvalidLengthATS');
            TL = comm.internal.utilities.convertInt2Bit(TLint, 8); % MSB first
            
            ATSData = [TL; formatByte; TA; TB; TC];
            ATSFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(ATSData));
            ATSStdFrame = nfcAddOddParityBits(ATSFrame);
            targetATSFrame = modulate(obj, ATSStdFrame);
            
            nfcPrint.Heading3('Target transmitted ATS in response to RATS');
        end
        function targetIBlockFrame = transmitIBlock(obj, data)
            % Initiator/PCD transmits I-Block to Target/PICC.
            % Reference: ISO/IEC 14443-4, section 7
            
            % Application layer provides data as string of hex numbers.
            % Convert data to transmit into bits, from a string of hex numbers.
            dataBits = nfcBase.convertHexStr2Bit(data);
            
            % MSB first
            PCB = double([0; 0; ... % I-Block
                0; ...
                0; ... % Chaining not supported
                1; ... % CID supported
                0; ... % NAD not supported
                1; obj.pBlockNumber]);
            % CID supported, so add card identifier field
            cardIdentifier = [0; 0; 0; 0; obj.pCID];
            prologueField = [PCB; cardIdentifier];
            
            iBlockData = [prologueField; dataBits];
            iBlockFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(iBlockData));
            coder.internal.errorIf(any(length(iBlockFrame) > 8*[obj.pFSD, obj.FSC]), ...
                'comm:NFC:InvalidLengthIBlock');
            iBlockStdFrame = nfcAddOddParityBits(iBlockFrame);
            targetIBlockFrame = modulate(obj, iBlockStdFrame);
        end
        function recData = receiveIBlock(obj, initiatorIBlockFrame)
            % Target/PICC receives I-Block from Initiator/PCD.
            % The information field (INF) of the I-Block is returned.
            % Reference: ISO/IEC 14443-4, section 7
            
            recIBlockBits = demodulate(obj, initiatorIBlockFrame);
            
            [isParityValid, recIBlockBits1] = nfcCheckOddParityBits(recIBlockBits);
            
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'I-Block');            
            
            [recIBlockBits2, err] = nfcCheckCRC(recIBlockBits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'I-Block');
            recIBlockBits3 = nfcByteWiseMSB2LSBFirst(recIBlockBits2);
            
            % Decode I-Block
            % As per Block numbering rules (Reference: ISO/IEC 14443-4,
            % section 7.5.3), Target/PICC "may"  check received block
            % number. Skip checking it for now.
            recIsPICCSupportsCID = recIBlockBits3(5, 1);
            recData1 = [];
            if recIsPICCSupportsCID
                % skip checking CID, as only 1 Target/PICC is supported for
                % now
                if length(recIBlockBits3) > 16
                    recData1 = recIBlockBits3(17:end, 1);
                end
            else
                if length(recIBlockBits3) > 8
                    recData1 = recIBlockBits3(9:end, 1);
                end
            end
            
            % Application layer expects data as string of hex numbers.
            % Convert received data bits into a string of hex numbers.
            recData = nfcBase.convertBit2HexStr(recData1(:));
        end
        function targetDESELECTFrame = receiveDESELECT(obj, initiatorDESELECTFrame)
            % Target/PICC receives DESELECT command from Initiator/PCD
            % and responds with DESELECT response.
            % Reference: ISO/IEC 14443-4, section 7
            
            recDESELECTBits = demodulate(obj, initiatorDESELECTFrame);
            
            [isParityValid, recDESELECTBits1] = nfcCheckOddParityBits(recDESELECTBits);
            
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'DESELECT');            
            
            [recDESELECTBits2, err] = nfcCheckCRC(recDESELECTBits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'DESELECT');
            recDESELECTBits3 = nfcByteWiseMSB2LSBFirst(recDESELECTBits2);
            
            % Decode DESELECT command
            desBits = recDESELECTBits3(3:4, 1);
            coder.internal.errorIf(~isequal(desBits, [0; 0]), ...
                'comm:NFC:InvalidDESELECT');
            
            nfcPrint.Heading2('Target received DESELECT');
            
            % Respond with DESELECT response
            % MSB first
            PCB = double([1; 1; ... % S-Block
                0; 0; ... % DESELECT
                1; ... % CID supported
                0; ...
                1; 0]);
            sBlockFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(PCB));
            sBlockStdFrame = nfcAddOddParityBits(sBlockFrame);
            targetDESELECTFrame = modulate(obj, sBlockStdFrame);
            
            nfcPrint.Heading3('Target transmitted DESELECT response');
        end

        function modOut = modulate(obj, bitsIn)
            % Modulate bitsIn for Target to Initiator communication as per ISO/IEC
            % 14443-2:2010, section 8
            % The first element of bitsIn follows 'Start communication' symbol i.e.
            % LSB-first transmission.
            
            sampPerSym = obj.SamplesPerSymbol;
            
            inSize = size(bitsIn);
            outSize = inSize;
            % 1 'Start Communication' & 1 'End Communication' symbols
            outSize(1) = sampPerSym * (inSize(1) + 2);
            % initialize output
            modOut = zeros(outSize, 'like', bitsIn);
            
            seqD = getSequenceD(obj);
            seqE = getSequenceE(obj);
            seqF = getSequenceF(obj);
            
            % 'Start Communication' symbol
            modOut(1:sampPerSym) = seqD;
            
            % Modulate incoming bits
            for k=1:inSize(1)
                idx = k*sampPerSym + (1:sampPerSym);
                if bitsIn(k)
                    % a 1
                    modOut(idx) = seqD;
                else
                    % a 0
                    modOut(idx) = seqE;
                end
            end
            
            % 'End Communication' symbol
            idx = (inSize(1)+1)*sampPerSym + (1:sampPerSym);
            modOut(idx) = seqF;
        end
        function demodOut = demodulate(obj, rxIn)
            % Demodulate rxIn for Initiator-to-Target communication as per ISO/IEC
            % 14443-2:2010, section 8

            demodOut = [];
            sampPerSym = obj.SamplesPerSymbol;
            
            % Find the 'high' signal level
            % - There must be sampPerSym samples where the signal is 'high', either
            % due to sequence Y or due to no symbols at all.
            % - Use this high signal level to slice the signal into 1 & 0.
            inSize = size(rxIn);
            inAbs = abs(rxIn);
            decBoundary = mean(inAbs);
            for k=1:(inSize(1)-sampPerSym)
                oneSym = inAbs(k : k+sampPerSym-1, 1);
                mn = mean(oneSym);
                delta = oneSym - mn;
                % We are looking for high signal level that is flat over one
                % symbol. The threshold for flatness used here is 5% of mean. If we
                % find the high level, move on. Otherwise, check the next slice of
                % sampPerSym samples.
                if ~any(delta > 0.05*mn)
                    decBoundary = mn/2;
                    break
                end
            end
            
            if (decBoundary == 0)
                decBoundary = mean(inAbs);
            end
            
            % slice input to binary
            inBin = double(inAbs > decBoundary);
            
            % Find first low - that is the start of communication
            lowIdx = find(inBin == 0, 1);
            
            % Find second high over one symbol - this gives end of this low
            highIdx = find(inBin(lowIdx : lowIdx+sampPerSym-1, 1) == 1, 1);
            
            % Find next low. There must be a low in next 3 symbols. Otherwise, it
            % represents end of communication
            outIdx = 1;
            startIdx = lowIdx + highIdx - 1;
            
            while (highIdx < inSize(1))
                lowIdx = find(inBin(startIdx : inSize(1), 1) == 0, 1);
                if isempty(lowIdx)
                    % end of communication
                    % if the last two detected bits were 0, the last bit is part of
                    % end of communication sequence - remove it.
                    if (outIdx>3) && (demodOut(outIdx-1, 1)==0) && (demodOut(outIdx-2, 1)==0)
                        demodOut(outIdx-1, :) = [];
                    end
                    break;
                elseif lowIdx <= sampPerSym/2
                    % something went wrong - there must be a gap of more than half
                    % a symbol between two dips. skip this.
                    highIdx = lowIdx;
                    continue;
                elseif lowIdx < sampPerSym
                    % same as previous sequence
                    if outIdx == 1
                        % must be sequence Z i.e. logical 0
                        demodOut(outIdx, 1) = 0; %#ok<*AGROW>
                    else
                        demodOut(outIdx, 1) = demodOut(outIdx-1, 1);
                    end
                elseif lowIdx < 1.5*sampPerSym
                    if (outIdx == 1) || (demodOut(outIdx-1, 1) == 0)
                        % sequence ZX
                        demodOut(outIdx, 1) = 1;
                    else
                        % sequence XYZ
                        demodOut(outIdx, 1) = 0;
                        outIdx = outIdx + 1;
                        demodOut(outIdx, 1) = 0;
                    end
                elseif lowIdx < 2*sampPerSym
                    % sequence: XYX
                    demodOut(outIdx, 1) = 0;
                    outIdx = outIdx + 1;
                    demodOut(outIdx, 1) = 1;
                else
                    % end of communication
                    break;
                end
                outIdx = outIdx + 1;
                startIdx = startIdx + lowIdx - 1;
                highIdx = find(inBin(startIdx : inSize(1), 1) == 1, 1);
                if isempty(highIdx)
                    % There must be a corresponding 'high' to every 'low'.
                    % Corrupted signal. 
                    return
                end
                startIdx = startIdx + highIdx - 1;
            end
            
        end
    end
    
end

function nfcid3 = generateNFCID3()
    % 10 byte long random identifier NFCID3 of the Target used
    % during transport protocol activation.
    % It is a 80x1 column vector of bits. MSB-first (top).
    nfcid3 = randi([0,1], 80, 1);
end
