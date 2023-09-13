%% Section 1: Clear all variables
try
    uno.close; %close any existing arudino connections
catch 
        %if closing arduino fails, do nothing
end
clear all; clc; %clear all matlab variables and clear the workspace display


%% Section 2: Set Up Virtual Environment (MuJoCo)
% You should have MuJoCo open with a model loaded and running before
% starting this code!  If your code is crashing during this section, try
% the following: Close MuJoCo, Open MuJoCo, Open Model, Play MuJoCo, Run
% MATLAB Code.
[model_info, movements,command, selectedDigits_Set1, selectedDigits_Set2, VREconnected] = connect_hand;


%% Section 3: Connect to Arduino
[uno, ArduinoConnected]=connect_ard1ch();% can put the comport number in as an argument to bypass automatic connection, useful if more than one arduino uno is connected

%% Section 4: Plot (and control) in real time

% SET UP PLOT
[fig, animatedLines, Tmax, Tmin] = plotSetup1ch();

% INITIALIZATION
[data,control, dataindex, controlindex, prevSamp,previousTimeStamp]=init1ch();
tdata=[0];
tcontrol=[];
pause(0.5)
tic
%% %%%%%%%%%%%%%%%%%%%%%%% START OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%
csv_filename = 'raw_emg_rh.csv';        % Specify the desired filename
file_open = fopen(csv_filename, 'a');   % Create a file for writing in append mode
header_written = false;                 % Track if the CSV header has been written
windowSize = 88;        % Set the window size for the moving average
baselineSize = 3000;    % Samples to get the baseline value.
baselineflag = 0;       % Flag to process baseline just once.
baselineRMS = 0;
baselineSTD = 0;
epochSize = 10000;      % Epoch window size.
frequencyFlag = 0;
Fs = 1000;
Fn = Fs/2;
fco = 30;
L = 10000;
%% %%%%%%%%%%%%%%%%%%%%%%% END OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%
while(ishandle(fig)) %run until figure closes
    % SAMPLE ARDUINO
    try
        emg = uno.getRecentEMG; % gets the recent EMG values from the Arduino. Values returned will be between -2.5 and 2.5 . The size of this variable will be a 1 x up to 330
        if ~isempty(emg)
            [~,newsamps] = size(emg); % determine how many samples were received since the last call
            data(:,dataindex:dataindex+newsamps-1) = emg(1,:); % add new EMG data to the data vector
            dataindex = dataindex + newsamps; %update sample count
            controlindex = controlindex + 1;
        else
            disp('empty array') %if data from arduino is empty, display "empty array"
        end
    catch
        disp('error')
    end
    if ~isempty(emg)
        % UPDATE
        timeStamp = toc; %get timestamp
        % CALCULATE CONTROL VALUES
        try

            %% %%%%%%%%%%%%%%%%%%%%%%% START OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%
            % Write the header to the CSV file (once)
            if ~header_written
                fprintf(file_open, 'Time,RawData, ControlData\n');
                header_written = true;
            end
            % Check if there are at least 20 samples in 'data'
            if length(data) >= windowSize
                if ((dataindex >= baselineSize) && (baselineflag == 0)) % only gets here once
                    baselineData = zeros(length(data), 1); % Pre-allocate array to get the baseline data.
                    baselineData = data(1, 1:dataindex -1); % Get the current data
                    baselineRMS = rms(baselineData);
%                     baselineSTD = std(baselineData);
%                     baselineRMS
%                     baselineSTD
                    baselineflag = 1;
                end
                dataWindow = data(1, (dataindex - 1) - (windowSize - 1):dataindex -1);
                movingAvg = abs(dataWindow - mean(dataWindow));
                [b,a] = butter(2,fco * 1.25/Fn);
                linear_envelope = filtfilt(b, a, movingAvg);
                final_value = mean(linear_envelope);

%                 myControlValue = final_value;
                
                % Check if 'movingAvg' is less than 0.3
                if (baselineflag == 0)
                    myControlValue = 0; % Open hand
                elseif ((final_value <= baselineRMS) && (baselineflag == 1))
                    myControlValue = 0; % Open hand
                elseif (final_value * 5 > 0.6)
                    myControlValue = 1; 
                else
                    myControlValue = final_value * 5;% Close hand
                end
            else
                % Handle the case where there are not enough samples
                disp('Not enough samples in ''data'' to calculate moving average.');
            end
            time_stamp = (1:(newsamps)/Fs);
            for i = 1:newsamps
                fprintf(file_open, '%f,%f,%f\n', time_stamp(i), data((dataindex - newsamps) + i));
            end
            %myControlValue = data(1,dataindex-1); %set the control value to the most recent value of the EMG data. REPLACE THIS LINE

            %% %%%%%%%%%%%%%%%%%%%%%%%% END OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%%

            control(1,controlindex) = myControlValue; %update the control parameter with your control value
        catch
            disp('Something broke in your code!')
        end
        tcontrol(controlindex)=timeStamp; %update timestamp
        tempStart = tdata(end);
        tdata(prevSamp:dataindex-1)=linspace(tempStart,timeStamp,newsamps);

        % UPDATE PLOT
        [Tmax, Tmin] = updatePlot1ch(animatedLines, timeStamp, data, control, prevSamp, dataindex, controlindex, Tmax, Tmin);

        % UPDATE HAND
        if(VREconnected) %if connected
            status = updateHand(control, controlindex, command, selectedDigits_Set1, selectedDigits_Set2);
        end
        previousTimeStamp = timeStamp;
        prevSamp = dataindex;
    end
end
%% Section 5: Plot the data and control values from the most recent time running the system
data = data(~isnan(data)); %data is initialized and space is allocated as NaNs. Remove those if necessary.
control = control(~isnan(control)); %data is initialized and space is allocated as NaNs. Remove those if necessary.
finalPlot(data,control,tdata,tcontrol) %plot data and control with their respective timestamps
fclose(file_open);  % Close the CSV file when finished

%% Section 6: Close the arduino serial connection before closing MATLAB
uno.close;
