function sample_data = aquadoppNortekVelocityBeam2EnuPP( sample_data, qcLevel, auto )
% AQUADOPPNORTEKVELOCITYBEAM2ENUPP transforms Nortek velocity data expressed in 
% Beam coordinates to Easting Northing Up (ENU) coordinates. Only applies
% on FV01 dataset.
%
% We apply the provided Beam to XYZ matrix transformation to which we add
% the aquadopp attitude information (upward/downward looking, heading, pitch
% and roll) following http://www.nortek-as.com/lib/forum-attachments/coordinate-transformation/view.
%
% Inputs:
%   sample_data - cell array of data sets.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with updated velocity variables in ENU coordinates.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Ashley Parker <ashley.parker@csiro.au> modified 2025 (derived from adcpNortekVelocityBeam2EnuPP.m)

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return; end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

for k = 1:length(sample_data)    
    % do not process if heading, pitch and roll not present in data set
    isMagCorrected = true;
    headingIdx = getVar(sample_data{k}.variables, 'HEADING');
    if ~headingIdx
        isMagCorrected = false;
        headingIdx  = getVar(sample_data{k}.variables, 'HEADING_MAG');
    end
    pitchIdx   = getVar(sample_data{k}.variables, 'PITCH');
    rollIdx    = getVar(sample_data{k}.variables, 'ROLL');
    if ~(headingIdx && pitchIdx && rollIdx), continue; end
  
    % do not process if no velocity data in beam coordinates
    vel1Idx  = getVar(sample_data{k}.variables, 'VEL1');
    vel2Idx  = getVar(sample_data{k}.variables, 'VEL2');
    vel3Idx  = getVar(sample_data{k}.variables, 'VEL3');
    if ~(vel1Idx && vel2Idx && vel3Idx), continue; end
      
    % do not process if transformation matrix not known
    if isfield(sample_data{k}.meta, 'beam_to_xyz_transform')
        T = sample_data{k}.meta.beam_to_xyz_transform;
    else
        continue;
    end
    
    vel1 = sample_data{k}.variables{vel1Idx}.data;
    vel2 = sample_data{k}.variables{vel2Idx}.data;
    vel3 = sample_data{k}.variables{vel3Idx}.data;
    
    % Check instrument orientation using STATUS variable
    % If instrument is pointing down (bit 0 in status equal to 1)
    % rows 2 and 3 must change sign
    statusIdx = getVar(sample_data{k}.variables, 'STATUS');
    if statusIdx
        status = sample_data{k}.variables{statusIdx}.data;
        % Get the most common orientation (mode of bit 0)
        adcpOrientations = single(bitget(status, 1, 'uint8'));
        adcpOrientation = mode(adcpOrientations);
        if adcpOrientation == 1
            % Downward looking instrument
            T(2,:) = -T(2,:);
            T(3,:) = -T(3,:);
        end
    end
    
    heading = sample_data{k}.variables{headingIdx}.data;
    pitch = sample_data{k}.variables{pitchIdx}.data;
    roll  = sample_data{k}.variables{rollIdx}.data;
      
    [nSample, nBin] = size(vel1);
    velENU = NaN(3, nSample, nBin);
    for i=1:nSample
        % heading, pitch and roll are the angles output in the data in degrees
        % Subtract 90 from heading to make instrument x comparable to earth x (East)
        hh = (heading(i) - 90) * pi/180;
        pp = pitch(i) * pi/180;
        rr = roll(i) * pi/180;
        
        % Make heading matrix
        H = [cos(hh) sin(hh) 0; ...
            -sin(hh) cos(hh) 0; ...
             0       0       1];
        
        % Make tilt matrix (Pitch and Roll combined)
        P = [cos(pp) -sin(pp)*sin(rr) -cos(rr)*sin(pp); ...
             0       cos(rr)          -sin(rr); ...
             sin(pp) sin(rr)*cos(pp)  cos(pp)*cos(rr)];
        
        % Make resulting transformation matrix
        R = H*P;
        
        % Given BEAM velocities, ENU coordinates are calculated as enu = R*T*beam
        for j=1:nBin
            velBeam = [vel1(i, j); vel2(i, j); vel3(i, j)];
            velENU(:, i, j) = R*T*velBeam;
        end
    end
    
    % Extract ENU velocity components into separate variables
    UCUR = squeeze(velENU(1, :, :))';
    VCUR = squeeze(velENU(2, :, :))';
    WCUR = squeeze(velENU(3, :, :))';
    
    Beam2EnuComment = ['aquadoppNortekVelocityBeam2EnuPP.m: velocity data in Easting Northing Up (ENU) coordinates has been calculated from velocity data in Beams coordinates ' ...
        'using heading and tilt information and instrument coordinate transform matrix.'];
    
    % we update or create the velocity values in ENU coordinates
    vars = {'UCUR', 'VCUR', 'WCUR'};
    velData = {UCUR, VCUR, WCUR};
    varSuffix = {'', '', ''};
    if ~isMagCorrected, varSuffix = {'_MAG', '_MAG', ''}; end
    for l=1:length(vars)
        varName = [vars{l} varSuffix{l}];
        curIdx = getVar(sample_data{k}.variables, varName);
        if curIdx
            % we update the velocity values in ENU coordinates
            sample_data{k}.variables{curIdx}.data = squeeze(velENU(l, :, :));
        
            % need to update the dimensions/coordinates in case velocity in Beam
            % coordinates would have been previously bin-mapped
            sample_data{k}.variables{curIdx}.dimensions = sample_data{k}.variables{vel1Idx}.dimensions;
            sample_data{k}.variables{curIdx}.coordinates = sample_data{k}.variables{vel1Idx}.coordinates;
            
            if ~isfield(sample_data{k}.variables{curIdx}, 'comment')
                sample_data{k}.variables{curIdx}.comment = Beam2EnuComment;
            else
                sample_data{k}.variables{curIdx}.comment = [sample_data{k}.variables{curIdx}.comment ' ' Beam2EnuComment];
            end
        else
            % we create a new variable for velocity values in ENU coordinates
            sample_data{k} = addVar(...
                sample_data{k}, ...
                varName, ...
                velData{l}, ...
                sample_data{k}.variables{vel1Idx}.dimensions, ...
                Beam2EnuComment, ...
                sample_data{k}.variables{vel1Idx}.coordinates);
        end
    end
  
    if ~isfield(sample_data{k}, 'history')
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', sample_data{k}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    end
end
