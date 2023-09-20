%% Section 1: Clear all variables
try
    uno.close; %close any existing arudino connections
catch 
        %if closing arduino fails, do nothing
end
clear all; clc; %clear all matlab variables and clear the workspace display

%% %%%%%%%%%%%%%%%%%%%%%%% START OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%
base_filename = 'EmgData';              % Specify the desired filename
suffix = 0;                             % Initialize a file name suffix counter
csv_filename = [base_filename, '_', num2str(suffix), '.csv'];    % Generate the full file name with the suffix
files= dir(fullfile(pwd, '*.csv'));
% Check if the file with the generated name already exists
for i = 1:numel(files)
    fileName = files(i).name;
    if any(isstrprop(fileName, 'digit'))
        % Increment the suffix and generate a new file name
        suffix = suffix + 1;
        csv_filename = [base_filename, '_', num2str(suffix), '.csv'];
    end
end
%% %%%%%%%%%%%%%%%%%%%%%%% END OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%

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
base_filename = 'EmgData';        % Specify the desired filename
suffix = 0;                             % Initialize a file name suffix counter
csv_filename = [base_filename, '_', num2str(suffix), '.csv'];    % Generate the full file name with the suffix
files= dir(fullfile(pwd, '*.csv'));
% Check if the file with the generated name already exists
% while exist(csv_filename, 'file') == suffix
for i = 1:numel(files)
    fileName = files(i).name;
    if any(isstrprop(fileName, 'digit'))
        % Increment the suffix and generate a new file name
        suffix = suffix + 1;
        csv_filename = [base_filename, '_', num2str(suffix), '.csv'];
    end
end
file_open = fopen(csv_filename, 'a');   % Create a file for writing in append mode
header_written = false;                 % Track if the CSV header has been written
windowSize = 88;        % Set the window size for the moving average
baselineSize = 1000;    % Samples to get the baseline value.
baselineflag = 0;       % Flag to process baseline just once.
baselineRMS = 0;
baselineSTD = 0;
epochSize = 10000;      % Epoch window size.
frequencyFlag = 0;
Fs = 1000;
Fn = Fs/2;
fco = 30;
L = 10000;
%+++++ Create a time-frequency plot that updates in real-time
% figure;
% h = imagesc([], [], []);
% axis xy; % Flip the y-axis
% colormap('jet');
% xlabel('Time (s)');
% ylabel('Frequency (Hz)');
% title('Real-Time Continuous Wavelet Transform of EMG Signal');
% colorbar;
% wavelet_name = 'cmor3-3'; % Wavelet type and parameters (adjust as needed)
% scales = 1:100; % Range of scales to analyze
% % Create a buffer to store incoming data
% buffer_size = 2 * Fs; % Adjust the buffer size as needed
% buffer_idx = 1;
% emg_buffer = zeros(1, buffer_size);
% Initialize parameters
Fs = 1000; % Sampling frequency (Hz)
wavelet_name = 'db4'; % Wavelet type (e.g., Daubechies 4)
level = 5; % Decomposition level (adjust as needed)
threshold = 's'; % Thresholding method ('soft' or 'hard')
threshold_multiplier = 3; % Threshold multiplier (adjust as needed)

% Initialize a buffer to store incoming EMG data
buffer_size = 2 * Fs; % Adjust the buffer size as needed
emg_buffer = zeros(1, buffer_size);
buffer_idx = 1;

% Create a figure for real-time plotting
figure;
h1 = subplot(2, 1, 1);
h2 = subplot(2, 1, 2);
title(h1, 'Original EMG Signal');
title(h2, 'Denoised EMG Signal');
%++++++
% Write the header to the CSV file (once)
if ~header_written
    fprintf(file_open, 'Time,RawData, ControlData\n');
    header_written = true;
end
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
            % Check if there are at least 20 samples in 'data'
            myControlValue = 0;
             if dataindex >= windowSize
                if ((dataindex >= baselineSize) && (baselineflag == 0)) % only gets here once
                    baselineData = zeros(length(data), 1); % Pre-allocate array to get the baseline data.
                    baselineData = data(1, 1:dataindex -1); % Get the current data
                    baselineRMS = rms(baselineData);
                    baselineSTD = std(baselineData);
                    baselineflag = 1;
                end
                dataWindow = data(1, (dataindex - 1) - (windowSize - 1):dataindex -1);
                %++++++++
                emg_data = data(1, (dataindex - 1) - (windowSize - 1):dataindex -1);
                % Update the buffer with new data
                if buffer_idx > buffer_size
                    emg_buffer(1:end-1) = emg_buffer(2:end);
                    buffer_idx = buffer_size;
                end
                emg_buffer(:,buffer_idx:buffer_idx + windowSize -1) = emg_data(1,:); % Add new data point to the buffer

                % Check if the buffer is full, then perform denoising
                if buffer_idx == buffer_size
                    % Perform wavelet decomposition
                    [C, L] = wavedec(emg_buffer, level, wavelet_name);
                    
                    % Estimate the noise standard deviation (assuming Gaussian noise)
                    % using the median absolute deviation (MAD)
                    mad_estimation = mad(C, 1) / 0.6745;
                    
                    % Apply soft or hard thresholding to remove noise
                    threshold_value = threshold_multiplier * mad_estimation;
                    try
                        % Apply soft or hard thresholding to remove noise
                        C_thresholded = wthresh(C, threshold, threshold_value);
                    
                        % Reconstruct the denoised signal
                        denoised_signal = waverec(C_thresholded, L, wavelet_name);
                        
                        % Plot the original and denoised signals in real-time
                        plot(h1, emg_buffer);
                        plot(h2, denoised_signal);
                        drawnow;
                    catch exception
                        % Handle any errors that may occur during the thresholding or reconstruction
                        disp('Error occurred during thresholding or reconstruction:');
                        disp(exception.message);
                    end
                end
                buffer_idx = buffer_idx + windowSize;
                %++++++++
                movingAvg = abs(dataWindow - mean(dataWindow));
                [b,a] = butter(2,fco * 1.25/Fn);
                linear_envelope = filtfilt(b, a, movingAvg);
                final_value = mean(linear_envelope);


                % Check if 'movingAvg' is less than baselineRMS noise
                if (baselineflag == 0)
                    myControlValue = 0; % Open hand
                elseif ((final_value <= baselineRMS) && (baselineflag == 1))
                    myControlValue = 0; % Open hand
                elseif (final_value * 12 > 1)
                    myControlValue = 1; 
                else
                    myControlValue = final_value * 12;% Close hand
                end
            else
                % Handle the case where there are not enough samples
                myControlValue = data(1,dataindex-1); %set the control value to the most recent value of the EMG data.
             end

            %% %%%%%%%%%%%%%%%%%%%%%%%% END OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%%

            control(1,controlindex) = myControlValue; %update the control parameter with your control value
        catch
            disp('Something broke in your code!')
            disp(exception.message);
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
% time_stamp = (1:(length(data))/Fs);
time_stamp = length(tdata);
for i = 1:(time_stamp -1)
    if time_stamp > 16000
        break;
    end
    % fprintf(file_open, '%f,%f,%f\n', time_stamp(i), data(i), control(i));
    fprintf(file_open, '%f,%f,%f\n', tdata(i), data(i), control(i));
end
fclose(file_open);  % Close the CSV file when finished
data = data(~isnan(data)); %data is initialized and space is allocated as NaNs. Remove those if necessary.
control = control(~isnan(control)); %data is initialized and space is allocated as NaNs. Remove those if necessary.
finalPlot(data,control,tdata,tcontrol) %plot data and control with their respective timestamps

%% Section 6: Close the arduino serial connection before closing MATLAB
uno.close;
