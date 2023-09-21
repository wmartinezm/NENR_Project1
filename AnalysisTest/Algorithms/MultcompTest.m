
% Get the current directory
current_directory = pwd;

% Get a list of all CSV files in the current directory
csv_files = dir(fullfile(current_directory, '*.csv'));
% Load your data into a table

dataTable = readtable('Algorithms.csv');

% Fit a repeated-measures model
% aov = anova(dataTable,"Participant")
aov = anova(dataTable,"Result")

% Display the results

% m = multcompare(aov,["ElectrodeLocation","Algorithm"])
% m = multcompare(aov,["Result","ElectrodeLocation"])
% m = multcompare(aov,["Result","Algorithm"])