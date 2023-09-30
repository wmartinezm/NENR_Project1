
clear, clc, close all

% Get the current directory
current_directory = pwd;

% Get a list of all CSV files in the current directory
csv_files = dir(fullfile(current_directory, '*.csv'));
% Load your data into a table

dataTable = readtable('Algorithms.csv');

% Fit a repeated-measures model
% aov = anova(dataTable,"Participant")
%aov = anova(dataTable,"Result")
% 
for i = 1:length(dataTable.ElectrodeLocation)
    if dataTable.ElectrodeLocation == "Extensor"
        dataTable.ElectrodeLocation(i) = 0;
    end
    if dataTable.ElectrodeLocation == "Flexor"
        dataTable.ElectrodeLocation(i) = 1;
    end
end



figure;
hold on;

% noAov_Algorth = kruskalwallis(dataTable.Result)
% nonNormAov
% Box plot (uncomment this section for a box plot)
boxplot(dataTable.Result,dataTable.ElectrodeLocation);
title("Electrode Location vs Success")
ylabel("0 is failure and 1 is success")
xlabel("Electrode Location 0=Extensor, 1=Flexor")
hold off;
figure;
hold on;
boxplot(dataTable.Result,dataTable.Participant);
title("Particpant vs success")
ylabel("0 is failure and 1 is success")
xlabel("Participant 0=Amputee, 1=Healthly")
hold off;
figure;
hold on;
boxplot(dataTable.Result,dataTable.Algorithm);
title("Algorithm vs success")
ylabel("0 is failure and 1 is success")
xlabel("Algorithm 0=muscele threshold control, 1=wavelet noise control")
% boxplot(dataTable.Result, ...
%     'Labels', {'A1', 'A2'});
% ylabel('SNR (dB)');
% title('0.01 Significance level');

% Add an indicator if there's a significant difference
% if p_value_extensor < 0.01 % Set your significance level here
%     text(1, max(max(extensor_data, flexor_data)) + 1, 'Extensor: Significant', 'HorizontalAlignment', 'center', 'Color', 'r');
% end
% 
% if p_value_flexor < 0.01 % Set your significance level here
%     text(2, max(max(extensor_data, flexor_data)) + 1, 'Flexor: Significant', 'HorizontalAlignment', 'center', 'Color', 'r');
% end

hold off;

% signrank for results vs algorithm, location, Participants
signrank_res_A = signrank(dataTable.Result, dataTable.Algorithm)

signrank_res_P = signrank(dataTable.Result, dataTable.Participant)

signrank_res_P = signrank(dataTable.Result, dataTable.Participant)

% figure;
% hold on;
% boxplot(signrank_res_P)
% hold off;
%signrank_res_P = signrank(dataTable.Result, dataTable.Participant);
% Display the results

% m = multcompare(aov,["ElectrodeLocation","Algorithm"])
% m = multcompare(aov,["Result","ElectrodeLocation"])
% m = multcompare(aov,["Result","Algorithm"])