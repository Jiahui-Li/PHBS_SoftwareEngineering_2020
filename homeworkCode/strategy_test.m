%% This file serves as a test script for the LongOnly strategy

%% Create a director
director = mclasses.director.HomeworkDirector([], 'homework_1');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum(2014, 5, 1);
initParameters.endDate = datenum(2014, 8, 31);
director.initialize(initParameters);

% register a strategy
PairTradingStrategy =  PairTradingStrategy(director.rootAllocator , 'group2');
strategyParameters = mclasses.strategy.longOnly.configParameter(PairTradingStrategy);
PairTradingStrategy.initialize(strategyParameters);

%% run strategies
load('/Users/lifangwen/Desktop/module4/software/homeworkCode/sharedData/mat/marketInfo_securities_china.mat')
director.reset();
director.set_tradeDates(aggregatedDataStruct.sharedInformation.allDates);
director.run();