classdef nfcInitiator < nfcBase
    % nfcInitiator NFC Initiator
    %
    % nfcInitiator object represents an NFC Initiator that is compliant
    % with ISO/IEC 18092 Information technology - Telecommunications and
    % information exchange between systems – Near Field Communications –
    % Interface and Protocol (NFCIP-1) standard. 
    
    %   Copyright 2016-2021 The MathWorks, Inc.
    
    properties (Access = 'public')
        % 't1', as a multiple of 1/Fc
        % t1 must be within a range - see Table 3 in ISO/IEC 14443-2:2010,
        % section 8. As described in the standard, t1 represents the width
        % of the low pulse in the Modified Miller symbol.
        t1 = 32;
        % Data to transmit to the Target. Maximum allowed length is 250
        % characters.
        UserData = 'Hello, from MathWorks.';
    end
    properties (Access = 'private')
        % Initiator State
        pState = nfcInitiatorState.None;
        % 'tx' is used in the spec, so using it here instead of 'pTx'.
        % Reference: ISO/IEC 14443-2:2010, section 8
        tx = 64; % pBitRateFactor/2
        pPartialTargetUID = [];
        % DS Bit rate divisor supported for sending data. This property can
        % be a scalar or a vector with maximum 7 elements. Valid values are
        % 1, 2, 4, 8, 16, 32 and 64. The default is 1. Reference: ISO/IEC
        % 18092, section 9.1
        % 'DS' is used in the spec, so using it here instead of 'pDS'
        DS = 1;
        % DR Bit rate divisor supported for receiving data This property
        % can be a scalar or a vector with maximum 7 elements. Valid values
        % are 1, 2, 4, 8, 16, 32 and 64. The default is 1. Reference:
        % ISO/IEC 18092, section 9.1
        % 'DR' is used in the spec, so using it here instead of 'pDR'
        DR = 1;
        % Received DSt - Send-bit rate divisor supported by Target.
        % Reference: ISO/IEC 18092, section 12.5.1.2
        % Initialize with 1 as only D=1 is supported for now. Once D=2,4
        % are supported, add them to initialization as well. D=1,2,4 are
        % must for each NFC device, while higher Ds are optional. Higher Ds
        % are exchanged during ATR, so they will get populated
        % appropriately here.
        pDSt = 1;
        % Received DRt - Receive-bit rate divisor supported by Target.
        % Reference: ISO/IEC 18092, section 12.5.1.2
        % Initialize with 1 as only D=1 is supported for now. Once D=2,4
        % are supported, add them to initialization as well. D=1,2,4 are
        % must for each NFC device, while higher Ds are optional. Higher Ds
        % are exchanged during ATR, so they will get populated
        % appropriately here.
        pDRt = 1;
        % This Initiator's NFCID3.
        % Reference: ISO/IEC 18092, section 12.5.1.1
        pNFCID3 = [];
        % Received NFCID3t - Target's NFCID3.
        % Reference: ISO/IEC 18092, section 12.5.1.2
        pNFCID3t
        % DIDi. Reference: ISO/IEC 18092, section 12.5.1.1
        % For now, make this a private property as only one initiator is
        % supported at a time. When support for multiple initiators
        % simultaneously is added, this needs to be a public property.
        pDIDi = [0 0 0 0 0 0 0 0]'
        % PNI. Reference: ISO/IEC 18092, section 12.6.1.1.1
        % PNI is 2-bit long, so its range is [0,3]. This property is a
        % scalar value in that range.
        pPNI = 0;
        % Index of the user data element that was transmitted in the latest
        % transaction
        pCurrentUserDataIdx = 0;
        % FSD The maximum size of a frame, in bytes, the Initiator/PCD can
        % receive. Valid values are 16, 24, 32, 40, 48, 64, 96, 128, 256.
        % Reference: ISO/IEC 14443-4, section 5.1
        % For now, maximum 256 bytes is supported.
        % 'FSD' is used in the spec, so using it here instead of 'pFSD'.
        FSD = 256;
        % FSDI, derived from FSD
        % For default FSD=256, FSDI=8
        pFSDI = 8;
        % Received SameDinEachDirection
        pSameDinEachDirection
        % CID - logical address of selected Target/PICC
        % Reference: ISO/IEC 14443-4, section 5.1
        pCID
        % Received pFSC - The maximum size of a frame, in bytes, the
        % Target/PICC can receive Valid values are 16, 24, 32, 40, 48, 64,
        % 96, 128, 256. The default value, as per the spec, is 32 bytes but
        % support the maximum (256) only for now.
        % Reference: ISO/IEC 14443-4, section 5.2.3.
        pFSC = 256;
        % Received pFSCI - FSC integer, derived from FSC
        % For FSC=256, FSCI=8
        pFSCI = 8;
        % Received SFGI, which codes a multiplier value for SFGT (Specific
        % Guard Time).
        % Reference: ISO/IEC 14443-4, section 5.2.5
        pSFGI
        % Received FWI, which codes a multiplier value for FWT (Frame
        % Waiting Time). 
        % Reference: ISO/IEC 14443-4, section 5.2.5
        pFWI
        % Received: Target/PICC supports CID (1) or not (0)
        % Reference: ISO/IEC 14443-4, section 5.2.5
        pPICCsupportsCID
        % Received: Target/PICC supports NAD (1) or not (0)
        % Reference: ISO/IEC 14443-4, section 5.2.5
        pPICCsupportsNAD
        % Block number. . Toggles between 0 and 1, so stored as logical.
        % Reference: ISO/IEC 14443-4, section 7
        pBlockNumber = false;
        % Time Scope to visualize Modified Miller modulation
        pTS
    end
    methods
        function obj = nfcInitiator(varargin)
            coder.internal.errorIf(mod(nargin,2) ~= 0, ...
                'comm:NFC:InvalidPVPairs');
            for i = 1:2:nargin
                obj.(varargin{i}) = varargin{i+1};
            end
            obj.tx = obj.pBitRateFactor/2;
            if obj.EnableVisualization
                % Initialize timescope
                % 9 symbols in REQA, so TimeSpan of 10 symbols                
                obj.pTS = timescope('Name', 'Modified Miller - 100% ASK', ...
                    'Title', 'REQA Command by Initiator', ...
                    'SampleRate',  (obj.Fc * obj.SamplesPerSymbol)/obj.pBitRateFactor, ...
                    'TimeSpanSource','property', ...
                    'TimeSpan', 10/(obj.Fc /obj.pBitRateFactor), ...
                    'Position', figposition([40, 50, 30, 30]));
            end
        end
        function disp(obj)
            s = struct('Fc', obj.Fc, ...
                'SamplesPerSymbol', obj.SamplesPerSymbol, ...
                't1', obj.t1, ...
                'AppLayer', obj.AppLayer, ...
                'UserData', obj.UserData, ...
                'EnableVisualization', obj.EnableVisualization);
            disp(s);
        end
        function set.t1(obj, value)
            validateattributes(value, {'numeric'}, ...
                {'real','scalar','integer','positive','>=',28,'<=',40.5}, ...
                'nfcInitiator.t1', 't1');
            obj.t1 = value;
        end
        function set.UserData(obj, value)
            % Maximum number of user bytes in Data Exchange Protocol is
            % 251. 4 such information PDUs can be sent each time a
            % communication link is established. So, a max of 1004 bytes
            % can be sent. However, limit the data to 250 for now.
            % Reference: ISO/IEC 18092, section 12.6
            value = convertStringsToChars(value);
            coder.internal.errorIf((length(value) > 250) || ~ischar(value), ...
                'comm:NFC:InvalidUserData');
            obj.UserData = value;
        end
        function t1InSamples = gett1InSamples(obj)
            t1InSamples = round(obj.SamplesPerSymbol * obj.t1 / obj.pBitRateFactor);
        end
        function txInSamples = gettxInSamples(obj)
            txInSamples = round(obj.SamplesPerSymbol * obj.tx / obj.pBitRateFactor);
        end
        function seqX = getSequenceX(obj)
            % Generate sequence X
            seqX = ones(obj.SamplesPerSymbol, 1);
            txInSamples = gettxInSamples(obj);
            t1InSamples = gett1InSamples(obj);
            offSamps = txInSamples + (1 : t1InSamples);
            seqX(offSamps) = 0;
        end
        function seqY = getSequenceY(obj)
            % Generate sequence Y
            seqY = ones(obj.SamplesPerSymbol, 1);
        end
        function seqZ = getSequenceZ(obj)
            % Generate sequence Z
            seqZ = ones(obj.SamplesPerSymbol, 1);
            t1InSamples = gett1InSamples(obj);
            offSamps = 1 : t1InSamples;
            seqZ(offSamps) = 0;
        end
        function setPartialTargetUID(obj, partialUID)
            coder.internal.errorIf(any(partialUID < 0) || any(partialUID > 2), ...
                'comm:NFC:InvalidUIDSize');
            obj.pPartialTargetUID = partialUID;
        end
        function partialUID = getPartialTargetUID(obj)
            partialUID = obj.pPartialTargetUID;
        end
        function state = getState(obj)
            state = obj.pState;
        end
        function setState(obj, state)
            obj.pState = state;
        end
        function nfcid3 = getNFCID3(obj)
            if isempty(obj.pNFCID3)
                obj.pNFCID3 = generateNFCID3();
            end
            nfcid3 = obj.pNFCID3;
        end
        function dsi = getDSi(obj)
            % Returned dsi is MSB first. Reference: ISO/IEC 18092, section
            % 12.5.1.1.1
            ds = obj.DS;
            dsi = zeros(4,1);
            dsi(1,1) = any(ds == 64);
            dsi(2,1) = any(ds == 32);
            dsi(3,1) = any(ds == 16);
            dsi(4,1) = any(ds == 8);
        end
        function dri = getDRi(obj)
            % Returned dri is MSB first. Reference: ISO/IEC 18092, section
            % 12.5.1.1.1
            dr = obj.DR;
            dri = zeros(4,1);
            dri(1,1) = any(dr == 64);
            dri(2,1) = any(dr == 32);
            dri(3,1) = any(dr == 16);
            dri(4,1) = any(dr == 8);
        end
        function setNFCID3t(obj, value)
            coder.internal.errorIf(length(value) ~= 80, ...
                'comm:NFC:InvalidNFCID3', 'NFCID3t');
            obj.pNFCID3t = value;
        end
        function DIDi = getDIDi(obj)
            DIDi = obj.pDIDi;
        end
        function setDSt(obj, dst)
            % dsi must be 8 bits long (BSi byte of ATR_REQ)
            dstVec = [64, 32, 16, 8]';
            dstToSet = dstVec(logical(dst(5:8,1)));
            obj.pDSt(end + (1:length(dstToSet))) = dstToSet;
        end
        function setDRt(obj, drt)
            % dsi must be 8 bits long (BRi byte of ATR_REQ)
            drtVec = [64, 32, 16, 8]';
            drtToSet = drtVec(logical(drt(5:8,1)));
            obj.pDRt(end + (1:length(drtToSet))) = drtToSet;
        end
        function dst = getDSt(obj)
            dst = obj.pDSt;
        end
        function drt = getDRt(obj)
            drt = obj.pDRt;
        end
        function pni = getPNI(obj)
            % Return PNI as a 2-bit column vector, MSB first
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
        function userData = getUserData(obj, maxLen)
            % userData is a MSB-first bit column vector
            uData = (obj.UserData(:))'; % ensure uData is a row vector
            if isempty(uData)
                userData = [];
                return
            end
            uDataLen = length(uData);
            if (obj.pCurrentUserDataIdx == 0)
                % None of the data is sent so far.
                dataLen = min(uDataLen, maxLen);
                % Convert to ascii
                userDataBytes = uint8(uData(1, 1:dataLen))';
                userData = double(comm.internal.utilities.convertInt2Bit(userDataBytes, 8));
                obj.pCurrentUserDataIdx = dataLen;
                
            elseif (obj.pCurrentUserDataIdx == uDataLen)
                % All of the data already sent.
                userData = [];
                obj.pCurrentUserDataIdx = 0;
            else
                % Some data already sent in previous transactions. Send
                % remaining data.
                remDataLen = uDataLen - obj.pCurrentUserDataIdx;
                dataLen = min(remDataLen, maxLen);
                % Convert to ascii
                userDataBytes = uint8(uData(1, obj.pCurrentUserDataIdx + (1:dataLen)))';
                userData = double(comm.internal.utilities.convertInt2Bit(userDataBytes, 8));
                obj.pCurrentUserDataIdx = obj.pCurrentUserDataIdx + dataLen;
            end
        end
        function cid = getCID(obj)
            % CID - logical address of selected Target/PICC
            % Reference: ISO/IEC 14443-4, section 5.1
            if isempty(obj.pCID)
                % generate a random CID between 0 & 14, inclusive
                obj.pCID = randi([0,14], 1);
            end
            cid = obj.pCID;                
        end
        function obj = setFSCI(obj, fsci)
            
            % fsci is 4-element bit vector, MSB first
            fsciInt = comm.internal.utilities.convertBit2Int(fsci, 4);
            
            % A Target/PICC setting FSCI = '9'-'F' is not compliant with this
            % standard. A received value of FSCI = '9'-'F' should be
            % interpreted by the Initiator/PCD as FSCI = '8' (FSC = 256 bytes).
            % Reference: ISO/IEC 14443-4, section 5.2.3
            
            % See Table 1 in ISO/IEC 14443-4 (section 5.1) for FSCI to FSC
            % conversion
            % FSC is in bytes
            switch fsciInt
                case 0
                    fsc = 16;
                case 1
                    fsc = 24;
                case 2
                    fsc = 32;
                case 3
                    fsc = 40;
                case 4
                    fsc = 48;
                case 5
                    fsc = 64;
                case 6
                    fsc = 96;
                case 7
                    fsc = 128;
                case 8
                    fsc = 256;
                otherwise
                    fsciInt = 8;
                    fsc = 256;
            end
            obj.pFSCI = fsciInt;
            obj.pFSC = fsc;
        end
        function obj = setSFGI(obj, sfgi)
            sfgiInt = comm.internal.utilities.convertBit2Int(sfgi, 4); % MSB first
            if (sfgiInt == 15)
                sfgiInt = 0;
            end
            obj.pSFGI = sfgiInt;
        end
        function obj = setFWI(obj, fwi)
            fwiInt = comm.internal.utilities.convertBit2Int(fwi, 4); % MSB first
            if (fwiInt == 15)
                fwiInt = 4;
            end
            obj.pFWI = fwiInt;
        end
        function toggleBlockNumber(obj)
            obj.pBlockNumber = ~obj.pBlockNumber;
        end

        % --- Protocol Methods --- %
        
        function REQA_ShortFrame = transmitREQA(obj)
            % In order to detect Targets in the operating field, a
            % Initiator repeatedly transmits REQA (REQuest command, Type A).
            % Reference: ISO/IEC 14443-3, section 6.4.1
            
            % Initiator sends REQA to Target
            % LSB first
            reqACode = obj.getREQA();
            % Transmission is LSB first
            REQA_ShortFrame = modulate(obj, reqACode);
            
            if obj.EnableVisualization
                % Visualize REQA to illustrate Modified Miller modulation
                obj.pTS(REQA_ShortFrame);
                release(obj.pTS);
            end
            
            nfcPrint.Heading1('Initiator transmitted REQA');
        end
        function [isATQAValid, isCollisionDetected, doesTargetSupportBFA] = ...
                receiveATQA(obj, atqAStandardFrame)
            % Initiator receives ATQA (Answer To Request) from Target and
            % validates it.
            % Reference: ISO/IEC 14443-3, section 6.5.2
            
            isATQAValid = false;
            isCollisionDetected = false;
            % Initialize doesTargetSupportBFA to true as otherwise it is not a
            % complaint Target
            doesTargetSupportBFA = true;
            targetUIDSize = [];
            
            recAtqA = demodulate(obj, atqAStandardFrame);
            
            % ATQA is 16 bits long + 2 Parity bits
            if (length(recAtqA) ~= 18)
                % A collision occurred between ATQA sent by multiple
                % Targets.
                isCollisionDetected = true;
                nfcPrint.Heading1('Initiator detected collision while receiving ATQA');
                return
            end
            
            [isParityValid, msg] = nfcCheckOddParityBits(recAtqA);
            
            if isParityValid
                doesTargetSupportBFA = (sum(msg(1:5,1)) == 1); % only 1 of b1-b5 must be 1
                targetUIDSize = comm.internal.utilities.convertBit2Int(flipud(msg(7:8,1)), 2);
                % rest of the bits must be 0
                isATQAValid = ~any([msg(6,1);msg(9:16,1)]);
                % else
                % parity check failed - return isATQAValid = false (default)
                % nothing to do
            end
            
            nfcPrint.Heading1('Initiator received ATQA');
            localPrint(doesTargetSupportBFA, targetUIDSize);
            
        end
        function [initiatorACFrame, cLevel, uidComplete, isoCompliantTarget] = ...
                antiCollisionLoop(obj, targetACFrame, cLevel)
            
            coder.internal.errorIf(~any(cLevel==[1,2]), 'comm:NFC:UnsupportedCascadeLevel');
            
            uidComplete = false;
            isoCompliantTarget = false;
            
            if (cLevel == 1) && isempty(targetACFrame)
                % first step of cascade level 1
                
                sel = obj.getSEL(cLevel); % LSB first
                nvb = obj.getNVB(0); % # of data bits = 0; LSB first
                setState(obj, nfcInitiatorState.Sent_ANTICOLLISION_Cmd);
                initiatorACCmd1WithParityBits = nfcAddOddParityBits([sel; nvb]);
                initiatorACFrame = modulate(obj, initiatorACCmd1WithParityBits);
                nfcPrint.Heading3('Initiator transmitted ANTICOLLISION command');
                return
            end
            
            initiatorACRec1 = demodulate(obj, targetACFrame);
            
            if (getState(obj) == nfcInitiatorState.Sent_SELECT_Cmd)
                % Initiator sent NVB=70 in previous go-around, so it is waiting for SAK now
                
                [isParityValid, msg] = nfcCheckOddParityBits(initiatorACRec1);
                if isParityValid
                    [recSAK, err] = nfcCheckCRC(msg);
                    coder.internal.errorIf(err~=0, 'comm:NFC:CRCFailedCL', cLevel);
                    
                    nfcPrint.Heading3('Initiator received SAK');

                    recSAK = nfcByteWiseMSB2LSBFirst(recSAK);
                    initiatorACFrame = [];
                    if (recSAK(6) == 0) % check b3
                        % UID complete. exit Anticollision loop.
                        nfcPrint.Heading4('UID complete. Exit Anticollision loop.');
                        uidComplete = true;
                        setState(obj, nfcInitiatorState.AntiCollisionLoop_Complete);
                        
                        if (recSAK(2) == 1) % check b7
                            % Target compliant with NFCIP-1 transport protocol
                            isoCompliantTarget = true;
                            % else
                            % Target NOT compliant with NFCIP-1 transport protocol
                            % do nothing as default value of isoCompliantTarget = false
                        end
                    else
                        % UID not complete. Move to next cascade level
                        nfcPrint.Heading4('UID not complete. Increment Cascade Level.');
                        
                        cLevel = cLevel + 1;
                        
                        sel = obj.getSEL(cLevel); % LSB first
                        nvb = obj.getNVB(0); % # of data bits = 0; LSB first
                        setState(obj, nfcInitiatorState.Sent_ANTICOLLISION_Cmd);
                        initiatorACCmd1WithParityBits = nfcAddOddParityBits([sel; nvb]);
                        initiatorACFrame = modulate(obj, initiatorACCmd1WithParityBits);
                        
                        nfcPrint.Heading4('Initiator transmitted ANTICOLLISION command');
                    end
                    
                else
                    error(message('comm:NFC:CRCFailedCL', cLevel));
                end
                
            else
                % getState(initiatorCfg) ~= nfcInitiatorState.Sent_SELECT_Cmd
                
                nBytesExp = 5; % 4 uid + 1 BCC or 1 CT + 3 UID + 1 BCC
                nBitsPerByte = 9; % 9 bits/byte, including Parity Bit
                nBitsExp = nBytesExp * nBitsPerByte;
                initiatorACRec1Len = length(initiatorACRec1);
                coder.internal.errorIf(initiatorACRec1Len > nBitsExp, ...
                    'comm:NFC:InvalidNumBitsReceivedCL', nBitsExp, initiatorACRec1Len, cLevel);
                
                if (initiatorACRec1Len == nBitsExp)
                    % full msg received - no collision
                    
                    nfcPrint.Heading3(sprintf('Initiator received CL%d UID without collision', cLevel));
                    initiatorACFrame = receivedFullUIDCLn(obj, initiatorACRec1, cLevel);
                    
                else
                    % initiatorACRec1Len < nBitsExp
                    % partial msg received - two possibilities : a) collision occurred;
                    % b) Target (re-)transmitted its partial UID in response to a collision
                    % that occurred in the previous try.
                    
                    partialTargetUID = getPartialTargetUID(obj);
                    if isempty(partialTargetUID)
                        % case a) collision occurred
                        % cache away the received partial UID & send it back to Target with a
                        % 1 bit appended to break the contention between the two Targets.
                        
                        setPartialTargetUID(obj, initiatorACRec1);
                        
                        % Resend initiatorACRec1 directly (it already has Parity bits) after
                        % appending a 1 bit to break contention between 2 Targets.
                        sel = obj.getSEL(cLevel);
                        nvb = obj.getNVB(initiatorACRec1Len+1); % (+1) for additional bit
                        data = [nfcAddOddParityBits([sel; nvb]); initiatorACRec1; 1];
                        initiatorACFrame = modulate(obj, data);
                    else
                        % case b) Target (re-)transmitted its partial UID in response to a
                        % collision that occurred in the previous try.
                        
                        storedUID = getPartialTargetUID(obj);
                        recFullUID = [storedUID; initiatorACRec1];
                        % ensure recFullUID is 5 bytes long (nBitsExp bits long)
                        coder.internal.errorIf(length(recFullUID) ~= nBitsExp, ...
                            'comm:NFC:InvalidUIDLength');
                        initiatorACFrame = receivedFullUIDCLn(obj, recFullUID, cLevel);
                        
                    end
                end
            end
        end
        function initiatorATR_REQFrame = transmitATR_REQ(obj)
            % Initiator transmits ATR_REQ (Attribute Request) to Target. This is
            % the first step after a Target is selected during Anticollision loop.
            % Reference: ISO/IEC 18092, section 12.5.1.1
            
            % ATR_REQ
            CMD1 = [1 1 0 1 0 1 0 0]'; % xD4; MSB-first
            CMD2 = [0 0 0 0 0 0 0 0]';% x00;
            NFCID3i = getNFCID3(obj);
            % DIDi=0, as modeling only single Target for now.
            DIDi = getDIDi(obj);
            BSi = [0; 0; 0; 0; getDSi(obj)];
            BRi = [0; 0; 0; 0; getDRi(obj)];
            % Initiator does not support NFC-SEC (for now)
            SECi = 0;
            % Length Reduction value - set it to up to Byte 64 valid in Transport
            % Data.
            LRi = [0 0]';
            % General bytes are not used
            Gi = 0;
            % Initiator does not use NAD
            NAD = 0;
            PPi = [SECi; 0; LRi; 0; 0; Gi; NAD];
            transportDataField = [CMD1; CMD2; NFCID3i; DIDi; BSi; BRi; PPi];
            startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
            lengthByteInt = (length(transportDataField)/8) + 1;
            obj.validateLENByte(lengthByteInt, 'ATR_REQ');
            lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
            atrReq = [startByte; lengthByte; transportDataField];
            atrReqFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(atrReq));
            atrReqStdFrame = nfcAddOddParityBits(atrReqFrame);
            initiatorATR_REQFrame = modulate(obj, atrReqStdFrame);
            
            nfcPrint.Heading2('Initiator transmitted ATR_REQ');
            
        end
        function initiatorPSL_REQFrame = receiveATR_RES(obj, targetATR_RESFrame)
            % Initiator receives ATR_RES (Attribute Request Response) from
            % Target and responds with PSL_REQ (Parameter Selection Request).
            % Reference: ISO/IEC 18092, section 12.5.1.2 (ATR_RES) & 12.5.3.1 (PSL_REQ)
            
            recATR_RESBits1 = demodulate(obj, targetATR_RESFrame);            

            [isParityValid, recATR_RESBits2] = nfcCheckOddParityBits(recATR_RESBits1);
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'ATR_RES');
            
            [recATR_RESBits3, err] = nfcCheckCRC(recATR_RESBits2);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'ATR_RES');

            recATR_RESBits4 = nfcByteWiseMSB2LSBFirst(recATR_RESBits3);
            
            nfcPrint.Heading2('Initiator received ATR_RES');
            
            % Decode ATR_RES
            
            % First byte is the Start Byte which is 0xF0.
            recDataLen = length(recATR_RESBits4);
            recLengthByte = recATR_RESBits4(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'ATR_RES');
            recCMD1 = recATR_RESBits4(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 5]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'ATR_RES', 'xD5');
            recCMD2 = recATR_RESBits4(25:32, 1); %#ok<NASGU>
            recNFCID3t = recATR_RESBits4(33:112, 1); % 10 bytes = 80 bits
            setNFCID3t(obj, recNFCID3t);
            recDIDt = recATR_RESBits4(113:120, 1);
            coder.internal.errorIf(~isequal(recDIDt, [0 0 0 0 0 0 0 0]'), ...
                'comm:NFC:TPActivationSingleTargetOnly');
            coder.internal.errorIf(~isequal(recDIDt, getDIDi(obj)), ...
                'comm:NFC:InvalidRxDIDt');
            recBSt = recATR_RESBits4(121:128, 1);
            setDSt(obj, recBSt);
            recBRt = recATR_RESBits4(129:136, 1);
            setDRt(obj, recBRt);
            recTO = recATR_RESBits4(137:144, 1); %#ok<NASGU>
            recPPt = recATR_RESBits4(145:152, 1); %#ok<NASGU>
            
            % Respond with PSL_REQ (Parameter Selection Request).
            % Reference: ISO/IEC 18092, section 12.5.3.1
            
            CMD1 = [1 1 0 1 0 1 0 0]'; % xD4; MSB first
            CMD2 = [0 0 0 0 0 1 0 0]'; % x04; MSB first
            DID = getDIDi(obj);
            % The mechanism below chooses the fastest common rate between
            % DSi-DRt for DSI & between DRi-DSt for DRI. For now, all (DSi, DRi,
            % DSt, DRt) are set to 1, so D=1 will be picked.
            %
            dsi = obj.DS;
            drt = getDRt(obj);
            commonD = max(intersect(dsi, drt));
            % commonD can't be empty as at least D=1 must be supported by all
            % NFC devices
            coder.internal.errorIf(isempty(commonD), 'comm:NFC:NoCommonD');
            coder.internal.errorIf(commonD~=1, 'comm:NFC:InvalidD');
            DSI = comm.internal.utilities.convertInt2Bit(log2(commonD),3);
            dsiRate = mapD2Rate(commonD);
            dri = obj.DR;
            dst = getDSt(obj);
            commonD = max(intersect(dri, dst));
            % commonD can't be empty as at least D=1 must be supported by all
            % NFC devices
            coder.internal.errorIf(isempty(commonD), 'comm:NFC:NoCommonD');
            coder.internal.errorIf(commonD~=1, 'comm:NFC:InvalidD');
            DRI = comm.internal.utilities.convertInt2Bit(log2(commonD),3);
            driRate = mapD2Rate(commonD);
            BRS = [0; 0; DSI; DRI];
            % Length Reduction value - set it to up to Byte 64 valid in Transport
            % Data.
            LR = [0 0]';
            FSL = [0; 0; 0; 0; 0; 0; LR];
            transportDataField = [CMD1; CMD2; DID; BRS; FSL];
            startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
            lengthByteInt = (length(transportDataField)/8) + 1;
            obj.validateLENByte(lengthByteInt, 'PSL_REQ');
            lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
            pslReq = [startByte; lengthByte; transportDataField];
            pslReqFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(pslReq));
            pslReqStdFrame = nfcAddOddParityBits(pslReqFrame);
            initiatorPSL_REQFrame = modulate(obj, pslReqStdFrame);
            
            nfcPrint.Heading3('Initiator transmitted PSL_REQ in response to ATR_REQ');
            nfcPrint.Heading3(sprintf('Selected send rate: %d Kbps', dsiRate));
            nfcPrint.Heading3(sprintf('Selected receive rate: %d Kbps', driRate));
        end
        function status = receivePSL_RES(obj, targetPSL_RESFrame)
            % Initiator receives PSL_RES (Parameter Selection Response) from Target.
            % Reference: ISO/IEC 18092, section 12.5.3.2
            
            recPSL_RESBits1 = demodulate(obj, targetPSL_RESFrame);
            
            [isParityValid, recPSL_RESBits2] = nfcCheckOddParityBits(recPSL_RESBits1);
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'PSL_RES');
            
            [recPSL_RESBits3, err] = nfcCheckCRC(recPSL_RESBits2);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'PSL_RES');
            recPSL_RESBits4 = nfcByteWiseMSB2LSBFirst(recPSL_RESBits3);
            
            nfcPrint.Heading2('Initiator received PSL_RES');
            
            % Decode PSL_RES
            
            % First byte is the Start Byte which is 0xF0.
            recDataLen = length(recPSL_RESBits4);
            recLengthByte = recPSL_RESBits4(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'PSL_RES');
            recCMD1 = recPSL_RESBits4(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 5]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'PSL_RES', 'xD5');
            recCMD2 = recPSL_RESBits4(25:32, 1); %#ok<NASGU>
            recDID = recPSL_RESBits4(33:40, 1);
            coder.internal.errorIf(~isequal(recDID, [0 0 0 0 0 0 0 0]'), ...
                'comm:NFC:TPActivationSingleTargetOnly');
            coder.internal.errorIf(~isequal(recDID, getDIDi(obj)), ...
                'comm:NFC:InvalidRxDIDt');
            
            status = true;
            
            nfcPrint.Heading3('PSL_RES validated. All selected rates confirmed');
        end
        function initiatorDEP_REQFrame = transmitInformationPDU(obj, userData, activateMI)
            % Initiator transmits Information PDU (Protocol Data Unit) of DEP
            % (Data Exchange Protocol) to Target as DEP_REQ (DEP Request).
            % This is the first step after Transport Protocol Activation.
            % Reference: ISO/IEC 18092, section 12.6
            
            CMD1 = comm.internal.utilities.convertInt2Bit([13, 4]', 4); % xD4; MSB first
            CMD2 = comm.internal.utilities.convertInt2Bit([0, 6]', 4); % x06; MSB first; DEP_REQ
            % Information PDU
            MI = activateMI; % activate Multiple Information (MI) chaining
            NAD = 0; % NAD not available
            DID = 0; % DID not available
            PNI = getPNI(obj);
            PFB = [0; 0; 0; MI; NAD; DID; PNI]; % 8-bits
            DEPHeader = [CMD1; CMD2; PFB];
            transportDataField = [DEPHeader; userData];
            startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
            lengthByteInt = (length(transportDataField)/8) + 1;
            obj.validateLENByte(lengthByteInt, 'DEP_REQ');
            lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
            depReq = [startByte; lengthByte; transportDataField];
            depReqFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(depReq));
            depReqStdFrame = nfcAddOddParityBits(depReqFrame);
            initiatorDEP_REQFrame = modulate(obj, depReqStdFrame);
            
            nfcPrint.Heading2('Initiator transmitted an Information PDU in DEP_REQ');
            nfcPrint.Heading3(sprintf('Initiator PNI: %d', comm.internal.utilities.convertBit2Int(PNI,2)));
            
        end
        function receivedPDUType = receiveDEP_RES(obj, targetDEP_RESFrame)
            % Initiator receives DEP_RES (Data Exchange Protocol Response) from
            % Target and responds with DEP_REQ (DEP Request).
            % Reference: ISO/IEC 18092, section 12.6
            
            recDEP_RESBits1 = demodulate(obj, targetDEP_RESFrame);
            
            [isParityValid, recDEP_RESBits2] = nfcCheckOddParityBits(recDEP_RESBits1);
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'DEP_RES');
            
            [recDEP_RESBits3, err] = nfcCheckCRC(recDEP_RESBits2);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'DEP_RES');
            recDEP_RESBits4 = nfcByteWiseMSB2LSBFirst(recDEP_RESBits3);

            % Decode DEP_RES
            
            % First byte is the Start Byte which is 0xF0. 
            recDataLen = length(recDEP_RESBits4);
            recLengthByte = recDEP_RESBits4(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'DEP_RES');
            recCMD1 = recDEP_RESBits4(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 5]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'DEP_RES', 'xD5');
            % CMD2 must be x07
            recCMD2 = recDEP_RESBits4(25:32, 1);
            recCMD2int = comm.internal.utilities.convertBit2Int(recCMD2, 4);
            coder.internal.errorIf(~isequal(recCMD2int, [0, 7]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD2', 'DEP_REQ', 'x07');
            recPFB = recDEP_RESBits4(33:40, 1);
            recMI = recPFB(4, 1);
            % first 3 bits of recPFB indicate Information or ACT/NACK PDU
            if isequal(recPFB(1:3,1), [0 0 0]')
                % Information PDU
                receivedPDUType = nfcDEP_PDU_Type.Information;
                nfcPrint.Heading2('Initiator received an Information PDU in DEP_RES');
                % MI chaining must be off
                coder.internal.errorIf(recMI ~= 0, ...
                    'comm:NFC:MIMustBeZero');
            elseif isequal(recPFB(1:3,1), [0 1 0]')
                % ACK/NACK PDU
                receivedPDUType = nfcDEP_PDU_Type.ACK_OR_NACK;
                nfcPrint.Heading2('Initiator received a ACK/NACK PDU in DEP_RES');
                % MI chaining must be activated
                coder.internal.errorIf(recMI ~= 1, ...
                    'comm:NFC:MIMustBeOne');
            else
                coder.internal.error('comm:NFC:InvalidPDUType');
            end
            % received PNI must match
            recPNI = recPFB(7:8, 1);
            coder.internal.errorIf(~isequal(recPNI, getPNI(obj)), ...
                'comm:NFC:InvalidRxPNI');
            
            nfcPrint.Heading3(sprintf('Received Target PNI: %d', comm.internal.utilities.convertBit2Int(recPNI,2)));
            incrementPNI(obj);
            
        end
        function initiatorRLS_REQFrame = transmitRLS_REQ(obj)
            % Initiator transmits RLS_REQ (Release request) to Target to
            % release it & end the communication.
            % Reference: ISO/IEC 18092, section 12.7.2
            
            CMD1 = comm.internal.utilities.convertInt2Bit([13, 4]', 4); % xD4; MSB first
            CMD2 = comm.internal.utilities.convertInt2Bit([0, 10]', 4); % x0A; MSB first; DEP_REQ
            % DID is optional in RLS_REQ. As DID is not used, it is not sent.
            DEPHeader = [CMD1; CMD2];
            transportDataField = DEPHeader;
            startByte = comm.internal.utilities.convertInt2Bit([15; 0], 4); % fixed. 0xF0. MSB first
            lengthByteInt = (length(transportDataField)/8) + 1;
            % Ensure that length byte is in the range [3, 255]
            coder.internal.errorIf((lengthByteInt < 3) || (lengthByteInt > 255), ...
                'comm:NFC:OddParityCheckFailed', 'RLS_REQ');
            lengthByte = comm.internal.utilities.convertInt2Bit(lengthByteInt, 8);
            rlsReq = [startByte; lengthByte; transportDataField];
            rlsReqFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(rlsReq));
            rlsReqStdFrame = nfcAddOddParityBits(rlsReqFrame);
            initiatorRLS_REQFrame = modulate(obj, rlsReqStdFrame);
            
            nfcPrint.Heading2('Initiator transmitted RLS_REQ');
        end
        function status = receiveRLS_RES(obj, targetRLS_RESFrame)
            % Initiator receives RLS_RES (Release Response) from Target.
            % Reference: ISO/IEC 18092, section 12.7.2
            
            status = false; %#ok<NASGU>
            recRLS_RESBits1 = demodulate(obj, targetRLS_RESFrame);            

            [isParityValid, recRLS_RESBits2] = nfcCheckOddParityBits(recRLS_RESBits1);
            coder.internal.errorIf(~isParityValid, 'comm:NFC:OddParityCheckFailed', 'RLS_RES'); 
            
            [recRLS_RESBits3, err] = nfcCheckCRC(recRLS_RESBits2);
            coder.internal.errorIf((err ~= 0), 'comm:NFC:CRCFailed', 'RLS_RES');
            recRLS_RESBits4 = nfcByteWiseMSB2LSBFirst(recRLS_RESBits3);
            
            % Decode RLS_RES
            
            % First byte is the Start Byte which is 0xF0.
            recDataLen = length(recRLS_RESBits4);
            recLengthByte = recRLS_RESBits4(9:16, 1);
            recLengthByteInt = comm.internal.utilities.convertBit2Int(recLengthByte, 8);
            % Ensure that lengthByte matches received data length
            coder.internal.errorIf(recLengthByteInt ~= (recDataLen/8)-1, ...
                'comm:NFC:InvalidRxDataLength', 'RLS_RES');
            recCMD1 = recRLS_RESBits4(17:24, 1);
            recCMD1int = comm.internal.utilities.convertBit2Int(recCMD1, 4);
            coder.internal.errorIf(~isequal(recCMD1int, [13, 5]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD1', 'RLS_RES', 'xD5');
            % CMD2 must be x0B
            recCMD2 = recRLS_RESBits4(25:32, 1);
            recCMD2int = comm.internal.utilities.convertBit2Int(recCMD2, 4);
            coder.internal.errorIf(~isequal(recCMD2int, [0, 11]'), ...
                'comm:NFC:ContentInCmdMustBe', 'CMD2', 'RLS_RES', 'x0B');
            status = true;
            
            nfcPrint.Heading2('Initiator received RLS_RES');
            nfcPrint.Heading3('Target released');
            
        end
        function initiatorRATSFrame = transmitRATS(obj)
            % Initiator/PCD transmits RATS (Request for Answer To Select)
            % to Target/PICC. This is the first step after a Target/PICC is
            % selected during Anticollision loop.            
            % Reference: ISO/IEC 14443-4, section 5.1
            
            startByte = comm.internal.utilities.convertInt2Bit([14; 0], 4); % 0xE0. MSB first
            % FSDI codes FSD which specifies maximum frame size that PCD could receive.
            FSDI = obj.pFSDI;
            % CID - logical address of selected PICC
            CID = getCID(obj);
            paramByte = comm.internal.utilities.convertInt2Bit([FSDI; CID], 4); % MSB first
            ratsFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst([startByte; paramByte]));
            ratsStdFrame = nfcAddOddParityBits(ratsFrame);
            initiatorRATSFrame = modulate(obj, ratsStdFrame);
            
            nfcPrint.Heading2('Initiator transmitted RATS');
        end
        function status = receiveATS(obj, targetATSFrame)
            % Initiator/PCD receives ATS (Answer To Select) from
            % Target/PICC. No parameter change is assumed here, so just a
            % success/failure status is returned.
            % Reference: ISO/IEC 14443-4, section 5.2 (ATS)
            
            status = false; %#ok<NASGU>
            recATSBits1 = demodulate(obj, targetATSFrame);
            
            [isParityValid, recATSBits2] = nfcCheckOddParityBits(recATSBits1);
            coder.internal.errorIf(~isParityValid, 'comm:NFC:OddParityCheckFailed', 'ATS'); 
            [recATSBits3, err] = nfcCheckCRC(recATSBits2);
            coder.internal.errorIf((err ~= 0), 'comm:NFC:CRCFailed', 'ATS'); 
            recATSBits4 = nfcByteWiseMSB2LSBFirst(recATSBits3);
            
            % Decode ATS
            
            recTL = recATSBits4(1:8, 1);
            TLint = comm.internal.utilities.convertBit2Int(recTL, 8);
            coder.internal.errorIf((TLint*8) ~= length(recATSBits4), ...
                'comm:NFC:InvalidTL');
            coder.internal.errorIf(TLint > (obj.FSD-2), ...
                'comm:NFC:InvalidLengthATS');
            
            % Flags to indicate if TA, TB, TC are transmitted
            isTA = false;
            isTB = false;
            isTC = false;
            if (TLint > 1)
                % Optional T0 format byte is transmitted by Target/PICC. Decode it.
                recT0 = recATSBits4(9:16, 1);
                % Is TA, TB, TC transmitted?
                isTA = (recT0(4,1) == 1);
                isTB = (recT0(3,1) == 1);
                isTC = (recT0(2,1) == 1);
                setFSCI(obj, recT0(5:8,1));
            else
                % Optional T0 format byte is NOT transmitted by Target/PICC. Set related
                % fields to defaults value as specified by spec.
                
                % Spec default for FSCI is 2 (FSC=4 bytes)
                setFSCI(obj, comm.internal.utilities.convertBit2Int(2,4));
            end
            
            % TA b8 - same or different D in each direction
            % Set to 1 (same D) for now i.e. ignore it. handle this once it
            % is supported in Target/PICC
            %
            % If TA is NOT transmitted, set related fields to default values as
            % specified by spec.
            % If received TA has b4=1, it should be interpreted by PCD as all 0s
            % (i.e. only 106 kbps in both directions)
            if ~isTA || (recATSBits4(21,1) == 1)
                % empty indicates no optional bit rates supported, which is the
                % spec default
                obj.pSameDinEachDirection = true;
                defaultVal = zeros(8,1);
                setDSt(obj, defaultVal);
                setDRt(obj, defaultVal);
                
            else
                % TA is transmitted & b4==0. Extract out transmitted
                % SameDinEachDirection, DS & DR.
                recTA(1:8, 1) = recATSBits4(17:24, 1);
                obj.pSameDinEachDirection = (recTA(1,1)==1);
                ds = [zeros(4,1); recTA(2:4); 0];
                dr = [zeros(4,1); recTA(6:8); 0];
                setDSt(obj, ds);
                setDRt(obj, dr);
            end
            if isTB
                % TB is transmitted
                recTB = recATSBits4(25:32, 1);
                setFWI(obj, recTB(1:4, 1));
                setSFGI(obj, recTB(5:8, 1));
            else
                % TB is NOT transmitted. Set related fields to default values as
                % specified by spec.
                setSFGI(obj, 0); % default spec value = 0
                setFWI(obj, comm.internal.utilities.convertInt2Bit(4,4)); % default spec value = 4
            end
            if isTC
                % TC is transmitted
                recTC = recATSBits4(33:40, 1);
                % b8 to b3 are all 0s                
                obj.pPICCsupportsCID = (recTC(7,1)==1);
                obj.pPICCsupportsNAD = (recTC(8,1)==1);
            else
                % TC is NOT transmitted. Set related fields to default values as
                % specified by spec.
                obj.pPICCsupportsCID = true;
                obj.pPICCsupportsNAD = false;
            end
            % Historical bytes not supported/transmitted. They are optional, as per
            % the spec. Reference: ISO/IEC 14443-4, section 5.2.7
            status = true;
            nfcPrint.Heading2('Initiator received ATS');
        end
        function initiatorIBlockFrame = transmitIBlock(obj, data)
            % Initiator/PCD transmits I-Block to Target/PICC.
            % Reference: ISO/IEC 14443-4, section 7

            % Application layer provides data as string of hex numbers.
            % Convert data to transmit into bits, from a string of hex numbers.
            dataBits = nfcBase.convertHexStr2Bit(data);

            % MSB first
            PCB = double([0; 0; ... % I-Block
                0; ...
                0; ... % Chaining not supported
                obj.pPICCsupportsCID; ...
                0; ... % NAD not supported
                1; obj.pBlockNumber]); 
            prologueField = PCB;
            if obj.pPICCsupportsCID
                cidBits = comm.internal.utilities.convertInt2Bit(getCID(obj), 4);
                cardIdentifier = [0; 0; 0; 0; cidBits];
                prologueField = [prologueField; cardIdentifier];
            end
            iBlockData = [prologueField; dataBits];
            iBlockFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(iBlockData));
            coder.internal.errorIf(any(length(iBlockFrame) > 8*[obj.FSD, obj.pFSC]), ...
                'comm:NFC:InvalidLengthIBlock');
            iBlockStdFrame = nfcAddOddParityBits(iBlockFrame);
            initiatorIBlockFrame = modulate(obj, iBlockStdFrame);            
        end
        function recData = receiveIBlock(obj, targetIBlockFrame)
            % Target/PICC receives I-Block from Initiator/PCD.
            % The information field (INF) of the I-Block is returned.
            % Reference: ISO/IEC 14443-4, section 7
            
            recIBlockBits = demodulate(obj, targetIBlockFrame);
            
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
        function initiatorDESELECTFrame = transmitDESELECT(obj)
            % Initiator/PCD transmits DESELECT command to Target/PICC.
            % Reference: ISO/IEC 14443-4, section 7

            % MSB first
            PCB = double([1; 1; ... % S-Block
                0; 0; ... % DESELECT
                obj.pPICCsupportsCID; ...
                0; ... 
                1; 0]); 
            sBlockFrame = nfcAddCRC(nfcByteWiseMSB2LSBFirst(PCB));
            sBlockStdFrame = nfcAddOddParityBits(sBlockFrame);
            initiatorDESELECTFrame = modulate(obj, sBlockStdFrame);
            
            nfcPrint.Heading2('Initiator transmitted DESELECT');
        end
        function status = receiveDESELECT_RES(obj, targetDESELECT_RESFrame)
            % Initiator/PCD receives DESELECT response from Target/PICC 
            % and responds with DESELECT response.
            % Reference: ISO/IEC 14443-4, section 7
            
            recDESELECT_RESBits = demodulate(obj, targetDESELECT_RESFrame);
            
            [isParityValid, recDESELECT_RESBits1] = nfcCheckOddParityBits(recDESELECT_RESBits);
            
            coder.internal.errorIf(~isParityValid, ...
                'comm:NFC:OddParityCheckFailed', 'DESELECT response');
            
            [recDESELECT_RESBits2, err] = nfcCheckCRC(recDESELECT_RESBits1);
            coder.internal.errorIf(err ~= 0, 'comm:NFC:CRCFailed', 'DESELECT response');
            recDESELECT_RESBits3 = nfcByteWiseMSB2LSBFirst(recDESELECT_RESBits2);
            
            % Decode DESELECT command
            desBits = recDESELECT_RESBits3(3:4, 1);
            status = isequal(desBits, [0; 0]);
            
            if status
                nfcPrint.Heading2('Initiator received DESELECT response');
                nfcPrint.Heading3('Target released');
            end
        end
        function modOut = modulate(obj, bitsIn)
            % Modulate bitsIn for Initiator to Target communication as per ISO/IEC
            % 14443-2:2010, section 8
            % The first element of bitsIn follows 'Start communication' symbol i.e.
            % LSB-first transmission.
            
            sampPerSym = obj.SamplesPerSymbol;
            
            inSize = size(bitsIn);
            outSize = inSize;
            % 1 'Start Communication' & 2 'End Communication' symbols
            outSize(1) = sampPerSym * (inSize(1) + 3);
            % initialize output
            modOut = zeros(outSize, 'like', bitsIn);
            
            seqX = getSequenceX(obj);
            seqY = getSequenceY(obj);
            seqZ = getSequenceZ(obj);
            
            % 'Start Communication' symbol
            modOut(1:sampPerSym) = seqZ;
            
            % Modulate incoming bits
            idx = sampPerSym + (1:sampPerSym);
            if bitsIn(1)
                % 1st bit is a 1
                modOut(idx) = seqX;
            else
                % 1st bit is a 0
                modOut(idx) = seqZ;
            end
            
            for k=2:inSize(1)
                idx = k*sampPerSym + (1:sampPerSym);
                if bitsIn(k)
                    % a 1
                    modOut(idx) = seqX;
                else
                    % a 0
                    if bitsIn(k-1)
                        % previous bit is a 1
                        modOut(idx) = seqY;
                    else
                        % previous bit is a 0 as well
                        modOut(idx) = seqZ;
                    end
                end
            end
            
            % 'End Communication' symbol
            idx = (inSize(1)+1)*sampPerSym + (1:sampPerSym);
            if bitsIn(inSize(1))
                % last bit is 1, so the logic 0 in 'End Communication' symbol must
                % be sequence Y
                modOut(idx) = seqY;
            else
                % last bit is 0, so the logic 0 in 'End Communication' symbol must
                % be sequence Z
                modOut(idx) = seqZ;
            end
            modOut((inSize(1)+2)*sampPerSym + (1:sampPerSym)) = seqY;
            
        end
        function demodOut = demodulate(obj, rxIn)
            % Demodulate rxIn for Target-to-Initiator communication as per ISO/IEC
            % 14443-2:2010, section 8
            
            demodOut = [];
            sampPerSym = obj.SamplesPerSymbol;
            
            % Find the 'steady' signal level i.e. the level that represents
            % unmodulated carrier.
            % - There must be sampPerSym samples where the signal is 'steady', either
            % due to sequence DE or sequence F (End of communication).
            % - Convert the signal to bipolar using this level
            % - also use this level to scale the 'preamble' in the
            % PreambleDetector, for better match
            inSize = size(rxIn);
            inAbs = abs(rxIn);
            steadySigLvl = 0; 
            for k=1:(inSize(1)-sampPerSym)
                oneSym = inAbs(k : k+sampPerSym-1, 1);
                mn = mean(oneSym);
                delta = oneSym - mn;
                % We are looking for steady signal level that is flat over one
                % symbol. The threshold for flatness used here is 2.5% of mean. If we
                % find the high level, move on. Otherwise, check the next slice of
                % sampPerSym samples.
                if ~any(delta > 0.025*mn)
                    steadySigLvl = mn;
                    break
                end
            end
            
            seqD = obj.getSequenceD();
            scaleFactor = steadySigLvl;
            if (steadySigLvl == 0)
                steadySigLvl = mean(inAbs);
                scaleFactor = max(inAbs);
            end
            seqD1 = (seqD-1)*scaleFactor;
            inSig = inAbs - steadySigLvl;
            
            prb = seqD1;
            prb(sampPerSym/2 + (1:(sampPerSym/2))) = -seqD1(1:sampPerSym/2);
            thres = 0.9*abs(sum(seqD1.*prb));

            % Correlate the input signal, using filter, with sequence D. A
            % modified sequence D is used to get better match in the input
            % signal.
            crossCor = filter(prb, 1, inSig);
            % Find the peaks that are above the threshold and are at least
            % one symbol apart.
            [~, peakIdx] = findpeaks(crossCor, 'MinPeakHeight', thres, ...
                'MinPeakDistance', sampPerSym-1);
            if isempty(peakIdx)
                % Not an NFC Initiator signal.
                return
            end
            
            % First peak is start of communication - sequence D. The
            % relative location of subsequent peaks indicate the bit value.
            m = 1;
            threshold1 = 1.25*sampPerSym;
            threshold2 = 1.75*sampPerSym;
            threshold3 = 2.25*sampPerSym;
            prev = 1; % sequence D
            for k=2:length(peakIdx)
                delta = peakIdx(k) - peakIdx(k-1);
                if delta < threshold1
                    demodOut(m,1) = prev; %#ok<*AGROW>
                elseif delta < threshold2
                    if (prev == 1)
                        demodOut(m,1) = 0;
                    else
                        % prev = 0
                        demodOut(m,1) = 0;
                        m = m + 1;
                        demodOut(m, 1) = 1;
                    end
                elseif delta < threshold3
                    if (prev == 1)
                        demodOut(m,1) = 0;
                        m = m + 1;
                        demodOut(m,1) = 1;
                    else
                        % Not expected. Continue.
                        if (m == 1)
                            continue;
                        else
                            m = m - 1;
                        end                        
                    end
                    
                else
                    % Not expected. Continue
                    if (m == 1)
                        continue;
                    else
                        m = m -1;
                    end                    
                end
                prev = demodOut(m,1);
                m = m + 1;
            end
            
        end
    end
    
    methods (Access = 'private')
        function initiatorACFrame = receivedFullUIDCLn(obj, initiatorACRecBits, cLevel)
            % initiatorACRecBits is full received Target UID for cascade level cLevel.
            
            [isParityValid, msg] = nfcCheckOddParityBits(initiatorACRecBits);
            if isParityValid
                
                % Check BCC
                recUID = msg(1:32, 1); % first 4 bytes
                recBCC = msg(33:40, 1); % last byte
                expBCC = nfcGenerateBCC(recUID);
                if isequal(recBCC, expBCC)
                    % Response: A standard frame that contains data bits and CRC_A
                    sel = obj.getSEL(cLevel); %
                    nvb = obj.getNVB(40); % # of data bits = 40
                    data = [sel; nvb; msg];
                    dataWithCRC = nfcAddCRC(data);
                    dataStdFrame = nfcAddOddParityBits(dataWithCRC);
                    initiatorACFrame = modulate(obj, dataStdFrame);
                    setState(obj, nfcInitiatorState.Sent_SELECT_Cmd);

                    if isequal(obj.pCascadeTag, recUID(8:-1:1,1))
                        % Complete UID not yet received
                        setPartialTargetUID(obj, recUID(9:32,1));
                        nfcPrint.Heading4(sprintf('Partial UID received: %s', obj.convertBit2Hex(nfcByteWiseMSB2LSBFirst(recUID(9:32,1)))));
                    else
                        % Full UID received
                        uidTmp = getPartialTargetUID(obj);
                        if isempty(uidTmp)
                            % Single UID and cascade level=1
                            fullUID = recUID;
                        else
                            % Double or Triple UID. Retrieve the previously
                            % received UID parts to make complete UID
                            fullUID = [uidTmp; recUID];
                        end
                        nfcPrint.Heading4(sprintf('Complete UID received: %s', obj.convertBit2Hex(nfcByteWiseMSB2LSBFirst(fullUID))));                        
                    end
                    nfcPrint.Heading4('Initiator transmitted SELECT command');
                    
                else
                    coder.internal.error('comm:NFC:BCCCheckFailedCL', cLevel);
                end
            else
                coder.internal.error('comm:NFC:OddParityCheckFailedCL', cLevel);
            end
        end
        
    end
    methods (Static)
        function nvb = getNVB(dataLength)
            % NVB, LSB first. When displayed, its MSB first.
            totalNumBits = dataLength + 16; % 8 for SEL + 8 for NVB
            uNibbleInt = floor(totalNumBits/8);
            uNibble = comm.internal.utilities.convertInt2Bit(uNibbleInt, 4);
            lNibbleInt = mod(totalNumBits, 8);
            lNibble = comm.internal.utilities.convertInt2Bit(lNibbleInt, 4);
            nvb = [uNibble; lNibble];
            if (nargout == 0)
                nvb = nfcInitiator.convertBit2Hex(nvb);
            else
                nvb = flipud(nvb);
            end
        end
    end
end

function nfcid3 = generateNFCID3()
    % 10 byte long random identifier NFCID3 of the Initiator used
    % during transport protocol activation.
    % It is a 80x1 column vector of bits. MSB-first (top).
    nfcid3 = randi([0,1], 80, 1);
end

function localPrint(doesTargetsupportBFA, targetUIDSize)
    if doesTargetsupportBFA
        nfcPrint.Heading2('Target supports bit frame anticollision');
    else
        nfcPrint.Heading2('Target does not supports bit frame anticollision');
    end
    switch targetUIDSize
        case 0
            nfcPrint.Heading2('Target''s UID size: single');
        case 1
            nfcPrint.Heading2('Target''s UID size: double');
        case 2
            nfcPrint.Heading2('Target''s UID size: triple');
            % otherwise
            % nothing to do
    end
end

function rate = mapD2Rate(d)
    rateVec = [106, 212, 424, 848, 1695, 3390, 6780];
    rate = rateVec(log2(d)+1);
end
