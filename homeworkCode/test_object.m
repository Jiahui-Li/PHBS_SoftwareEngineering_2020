
% test_signl��test_object�����ڲ���PairTradingSignal class, �ⲿ������ѻԸ��𿪷�
% code review: ������
% Writer : Li Jiahui 
% Date: 2020/06/06
% �ڶ����޸ĺ���

%generate the a test object of PairTradingSignal class with start date 20111031
%'734807' is the time stamp corresponding to the date 20111031
test = PairTradingSignal(734807);
%fill 29 days alpha and beta history into regressionAlphaHistory and regressionBetaHistory
test.initializeHistory;