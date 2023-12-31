
% Get the current directory
current_directory = pwd;

% Get a list of all CSV files in the current directory
csv_files = dir(fullfile(current_directory, '*.csv'));
% Load your data into a table
% Example:
dataTable = readtable('Algorithms.csv');

% Fit a repeated-measures model
rm = fitrm(dataTable, 'Result');

% Perform the two-way ANOVA
anovaResults = ranova(rm);

% Display the results
disp(anovaResults)