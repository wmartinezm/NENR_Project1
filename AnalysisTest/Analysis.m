% Get the current directory
current_directory = pwd;

% Get a list of all CSV files in the current directory
csv_files = dir(fullfile(current_directory, '*.csv'));

% Initialize an empty cell array to store RMS signals for each file
rms_signal_array = {};

% Loop through each CSV file in the current directory
for file_idx = 1:length(csv_files)
    % Read the CSV file
    file_path = fullfile(current_directory, csv_files(file_idx).name);
    data = csvread(file_path);

    % Get the RawData column
    raw_data = data(:, 2); % Assuming RawData is in the first column

    % Calculate the RMS noise from the first 300 samples
    noise_segment = raw_data(1:180);
    % rms_noise = sqrt(mean(noise_segment.^2));
    rms_noise = rms(noise_segment);

    % Initialize variables to detect EMG signals
    emg_signals = {}; % Cell array to store detected EMG signals

    % Define the start and end indices for each segment (adjust as needed)
    segment_start = {[3038, 4281, 5180, 5911, 6651, 7585, 8424, 9293, 10302, 11370];
                     [2034, 2995, 3903, 4884, 5522, 6469, 7110, 7781, 8528, 9218];
                     [1720, 3645, 4907, 5747, 7187, 8045, 8851, 9642, 11534, 12265];
                     [885, 1884, 2648, 3353, 4064, 4764, 5390, 6034, 6654, 7310];
                     [1693, 2759, 3445, 3945, 4571, 5614, 6729, 7853, 8400, 8965];
                     [1033, 1637, 2164, 2585, 3038, 3525, 3907, 4522, 5116, 5574];
                     [1090, 1957, 2968, 3956, 4871, 5910, 6048, 7966, 8811, 9587];
                     [1327, 2155, 2886, 3542, 4260, 4916, 5620, 6309, 6908, 7675];
                     [1515, 2197, 2743, 3367, 3923, 4717, 5366, 6053, 6728, 7323];
                     [3698, 4573, 5382, 5945, 6586, 7559, 7870, 8401, 9485, 10172];
                     [1215, 1769, 2367, 3177, 4289, 4892, 5491, 6266, 6846, 7321];
                     [1006,2165, 3165, 4031, 4784, 5462, 6206, 6982, 7643, 9267]};
    % segment_end = [600, 900, 1200, 1500, 1800, 2100, 2400, 2700, 3000, length(raw_data)];

    % Process the full RawData into segments
    % for seg_idx = 1:length(segment_start)
    for seg_idx = 1:10
        % start_idx = segment_start(idx_array(seg_idx));
        start_idx = segment_start{file_idx}(1, seg_idx);
        % end_idx = segment_end(seg_idx);

        % Extract the segment
        segment = raw_data(start_idx:start_idx + 180);

        % Store the segment in emg_signals_array
        emg_signals{seg_idx} = segment;
    end

    % Calculate the RMS for each detected EMG signal
    % rms_signals = cellfun(@(x) sqrt(mean(x.^2)), emg_signals);
    rms_signals = cellfun(@(x) rms(x), emg_signals);

    % Store the RMS signals in the array
    rms_signal_array{file_idx} = rms_signals;

    % Optional: You can perform further analysis or visualization here
    % Convert rms_signals to a cell array
    rms_signals_cell = num2cell(rms_signals);
    % Calculate SNR in decibels (dB)
    % snr_db_signals = 10 * log10((rms_signal^2) / (rms_noise^2));
    snr_db_signals = cellfun(@(x) 20 * log10((x.^2) / (rms_noise^2)), rms_signals_cell);
    snr_db_signals_array{file_idx} = snr_db_signals;

end

% Concatenate SNR values for participant one's extensor and flexor muscles
participant1_extensor = [snr_db_signals_array{1}, snr_db_signals_array{2}]; % Subarrays 1 and 2
participant1_flexor = [snr_db_signals_array{3}, snr_db_signals_array{4}];     % Subarrays 3 and 4

% Concatenate SNR values for participant two's extensor and flexor muscles
participant2_extensor = [snr_db_signals_array{7}, snr_db_signals_array{8}]; % Subarrays 7 and 8
participant2_flexor = [snr_db_signals_array{9}, snr_db_signals_array{10}];   % Subarrays 9 and 10

% Combine SNR data for all participants and electrodes
extensor_data = [participant1_extensor, participant2_extensor];
flexor_data = [participant1_flexor, participant2_flexor];

% Perform a statistical test (Wilcoxon signed-rank test) for each pair of electrodes
[p_value_extensor, ~] = signrank(participant1_extensor, participant2_extensor);
[p_value_flexor, ~] = signrank(participant1_flexor, participant2_flexor);
figure
hold on
histogram(extensor_data)
hold off

[p_value_flexVExt, ~] = signrank(flexor_data, extensor_data);

[p_value_flexVExt, ~] = signrank(flexor_data, extensor_data);

% Create a bar plot or box plot
figure;
hold on;

% Box plot (uncomment this section for a box plot)
boxplot([extensor_data', flexor_data'], ...
    'Labels', {'Extensor', 'Flexor'});
ylabel('SNR (dB)');
title('0.05 Significance level');

% Add an indicator if there's a significant difference
if p_value_extensor < 0.05 % Set your significance level here
    text(1, max(max(extensor_data, flexor_data)) + 1, 'Extensor: Significant', 'HorizontalAlignment', 'center', 'Color', 'r');
end

if p_value_flexor < 0.05 % Set your significance level here
    text(2, max(max(extensor_data, flexor_data)) + 1, 'Flexor: Significant', 'HorizontalAlignment', 'center', 'Color', 'r');
end

hold off;

% Description of the figure
figure_description = sprintf('This figure compares the Signal-to-Noise Ratio (SNR) between electrodes for two participants. The extensor and flexor muscles of both participants are considered. Wilcoxon signed-rank tests were performed to assess the significance of differences. The red text "Significant" indicates a significant difference at a significance level of 0.05.');
disp(figure_description);

% Load your data into a table
% Example:
dataTable = readtable('Algorithms.csv');

% Fit a repeated-measures model
rm = fitrm(dataTable, 'Result ~ Algorithm*ElectrodeLocation*Participant');

% Perform the two-way ANOVA
anovaResults = ranova(rm);

% Display the results
disp(anovaResults)