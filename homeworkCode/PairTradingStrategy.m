
%PairTradingStrategy��������ţ����޽๲ͬ����
%���޽ฺ��fields��constructor,generateOrders,examCurrPairList�Լ�autoupdateCurrPairListPnL�����ı�д
%��Ÿ���updateCurrPairList,orderSort,openPair��closePair �����ı�д

% Writer : Zong Yanjie
% Date: 2020/06/06
% �ڶ����޸ĺ���
% code review: ��͢����������
classdef PairTradingStrategy < mclasses.strategy.LFBaseStrategy
    
    properties(Access = public)
        signals;
        signalInitialized;
        winCounter;
        lossCounter;
        currPairList;
    end
    
    methods
        function obj = PairTradingStrategy(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
            obj.signalInitialized = 0;
            obj.winCounter=0;
            obj.lossCounter =0;
            obj.currPairList = cell(0);
        end
    
        % update the current pairtrading list through self-update,
        % examination and profit sorting.Then generate the Orders to be
        % trade tomorrow
        function [orderList, delayList] = generateOrders(obj, currDate, ~)
            orderList = [];
            delayList = [];
            if not(obj.signalInitialized)
               obj.signals = PairTradingSignal(currDate);
               obj.signalInitialized =1;
            end
            
            obj.autoupdateCurrPairListPnL(currDate);
            [cashAvailable, buyOrderList1, sellOrderList1] = obj.examCurrPairList(currDate);
            [buyOrderList2,sellOrderList2] = obj.updateCurrPairList(currDate,cashAvailable);
            orderList = [orderList,sellOrderList1,sellOrderList2,buyOrderList1,buyOrderList2];
            delayList = [delayList, 1,1,1,1];
        end
        
        
        % close the position while certain loss is beyond the level or the pairs back to the mean.
        function [cashAvailable, buyOrderList, sellOrderList] = examCurrPairList(obj,currDate)
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate );
            cashAvailable = obj.getCashAvailable('stockAccount');
            longwindTicker={};
            longQuant = [];
            shortwindTicker = {};
            shortQuant = [];
            
            sign = false; %the signal whether to close the position, set it here in case the currPairList is null
            for i=1:length(obj.currPairList)
                sign=false;%the signal whether to close the position
                if (obj.currPairList{1,i}.PnL<-0.02) % the rate of profit loss                      
                    lossCounter += 1;
                    sign=true;                  
                end
                
                if abs(obj.currPairList{1,i}.openZscore)<1%when the dislocation converge to 1 zscore, then close the pair
                    winConter += 1;
                    sign=true;
                end
                
                if sign==true % close the position
                    stock1=obj.currPairList{1,i}.stock1;
                    stock2=obj.currPairList{1,i}.stock2;
                    stockPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, stock1);
                    stockPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, stock2);
                    windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(stock1);
                    windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(stock2);
                    
                    if obj.currPairList{1,i}.stock1Position<0
                        longwindTicker{length(longwindTicker)+1,1} = windTickers1;
                        longQuant = [longQuant,0];%ƽ��ʱ��Ŀ���λ�趨Ϊ0
                    else
                        shortwindTicker{length(shortwindTicker)+1,1} = windTickers1;
                        shortQuant = [shortQuant,0];
                    end

                    if obj.currPairList{1,i}.stock2Position<0
                        longwindTicker{length(longwindTicker)+1,1} = windTickers2;
                        longQuant = [longQuant,0];
                    else
                        shortwindTicker{length(shortwindTicker)+1,1} = windTickers2;
                        shortQuant = [shortQuant,0];
                    end        
                    cashAvailable = cashAvailable+abs(obj.currPairList{1,i}.stock1Position*stockPrice1)*(1-2/10000)+abs(obj.currPairList{1,i}.stock2Position*stockPrice2)*(1-2/10000); 
                    obj.currPairList={obj.currPairList{1:i-1},obj.currPairList{i+1:end}};
                end
                
            end
            buyOrderList.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            buyOrderList.account = obj.accounts('stockAccount');
            buyOrderList.price = obj.orderPriceType;
            buyOrderList.assetCode = longwindTicker;
            buyOrderList.quantity = longQuant;

            sellOrderList.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
            sellOrderList.account = obj.accounts('stockAccount');
            sellOrderList.price = obj.orderPriceType;
            sellOrderList.assetCode =  shortwindTicker;
            sellOrderList.quantity = shortQuant;           
        end
        
        % update the PnL of each stock pair portfolio in CurrPairList, 
        % It compare the price and position between the currDate and the OpenDate.
        function currPairList = autoupdateCurrPairListPnL(obj,currDate)
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate ) ;
            for i=1:length(obj.currPairList)
                opendateLoc = find([obj.signals.timeList{:,1}]== obj.currPairList{1,i}.openDate) ;
                stock1=obj.currPairList{1,i}.stock1;
                stock2=obj.currPairList{1,i}.stock2;      
                stockPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, stock1);
                stockPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, stock2);
                originPrice1 = aggregatedDataStruct.stock.properties.close(opendateLoc, stock1);
                originPrice2 = aggregatedDataStruct.stock.properties.close(opendateLoc, stock2);
                obj.currPairList{1,i}.PnL=(stockPrice1-originPrice1)*currPairList{1,i}.stock1Position+(stockPrice2-originPrice2)*currPairList{1,i}.stock2Position/(abs(originPrice1*currPairList{1,i}.stock1Position)+abs(originPrice2*currPairList{1,i}.stock2Position));
            end
            
        end  
       



        % Writer : Li Fangwen 
        % Date: 2020/06/06
        % �ڶ����޸ĺ���
        % code review����͢��

        function  [buyOrderList,sellOrderList] = updateCurrPairList(obj,currDate,cashAvailable)

            %aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            % [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate );
            % ��͢��2020/06/05:dateҲֻ��ת��index��ʽ������signalParameters���ʵ����������õ�dataLoc����ʦ2000�����index������������timeList�����index��д��Ӧ�ú�ʹ��propertyNameList����
            % ���2020/06/06:�Ѿ��޸�

             % �ֱ��ҵ�expectedReturn��validity��zscore��beta��propertyNameList�ж�Ӧ������
            returnIndex = find(ismember(obj.signals.propertyNameList, 'expectedReturn'));
            validityIndex = find(ismember(obj.signals.propertyNameList, 'validity'));
            zscoreIndex = find(ismember(obj.signals.propertyNameList, 'zScore'));
            betaIndex = find(ismember(obj.signals.propertyNameList, 'beta'));

            % �ֱ��ҵ���ͬpair ��Ӧ��expectedReturn��validity��zscore�����صĽ�����ǵĶ�ά����
            currentExpect = obj.signals.signalParameters(:,:,end,1,1,returnIndex);
            currentVal = obj.signals.signalParameters(:,:,end,1,1,validityIndex);
            currentZscore =  obj.signals.signalParameters(:,:,end,1,1,zscoreIndex);

            %��Ϊû��ͨ������pair��Ӧ�Ľ������0������������ÿ��pair��validity�����Ƿ�zscore����2���߼��жϣ��������Ǿ�����Ϊһ��pair��ʵ��������ϣ����õ����ϱ�׼�Ľ���pair��
            %Ȼ������������expectReturn���õ����㽻�ױ�׼��pair��expectReturn
            avaliableExpect = currentVal.*currentExpect.*(currentZscore>2||currentZscore<-2).*tril(currentExpect);
            longwindTicker={};
            longQuant = [];
            shortwindTicker = {};
            shortQuant = [];
            %�ⲿ�ֵ��㷨˼���ǴӴ�С��avaliableExpect������10������currPairList���бȽϿ��Ƿ���롣ÿ�ζ�������һ�����Ƚϼ�����ɺ󣬰�����expectreturn���0����ֹ�´��ٴα�ѡ����
            for i= 1:10
                [maxDatatool,xtool] = max(avaliableExpect);
                x = xtool(1);
                [maxData,y] = max(maxDatatool); %x,y�Ƕ�Ӧ�����expectReturn��pair
                % ��͢��2020/06/04:������ÿ��ѭ���õ���x,y��ͬһ���ɣ��е����
                % ���2020/06/06:�Ѿ��޸ģ�֮ǰ���˰��ҹ���pair��expectreturnת��Ϊ�㣬���޸�
                if maxData>0
                    stock1 = x;
                    stoock2 = y;

                    %����Ŀǰ���������ͷ�磬ֻ�Ǳ����˸���zscore�жϵ���������zscore����2�����գ�zscoreС��-2������
                    stock1Position = -obj.signals.signalParameters(x,y,zscoreIndex,end,1,1)/abs(obj.signals.signalParameters(x,y,zscoreIndex,end,1,1));
                    stock2Position = obj.signals.signalParameters(x,y,betaIndex,end,1,1)*...
                        obj.signals.signalParameters(x,y,zscoreIndex,end,1,1)/abs(obj.signals.signalParameters(x,y,zscoreIndex,end,1,1)); 

                    openCost = 0;%�����Ȳ����㣬֮���ټ���
                    openZScore = obj.signals.signalParameters(x,y,zscoreIndex,end,1,1);
                    PnL = 0;
                    openDate = currDate+1;%�ڶ��쿪�̿���
                    beta = obj.signals.signalParameters(x,y,betaIndex,end,1,1);

                    newStruct = struct('stock1',stock1,'stoock2',stoock2,'stock1Position',stock1Position,'stock2Position',...
                    stock2Position,'openCost',openCost,'openZScore',openZScore,'PnL',PnL,'openDate',openDate,'expectReturn',maxData,'beta',beta);
                    obj.orderSort();%�������ٱȽϣ�expectReturn��С��������
                    % ��͢��2020/06/04:����﷨��̫�԰���orderSort()ֻ���������Ķ��������ã�������currPairListֱ�ӵ��ã�������һ����Ա������һ��cell��Ӧ����obj.orderSort()��
                    % ���2020/06/06:�Ѿ�������ʾ�޸�

                    if (length(currPairList)<10)%���currPairList����С��10��ֱ�ӿ��ֹ������
                        [longwindTicker,longQuant,shortwindTicker,shortQuant] = obj.openPair(newStruct,longwindTicker,longQuant,shortwindTicker,shortQuant);

                    else
                        if newStruct.expectReturn > obj.currPairList{1,1}.expectReturn %����µ����expectReturn���ߣ����滻pair
                            [longwindTicker,longQuant,shortwindTicker,shortQuant,cashAvailable] = obj.closePair(obj.currPairList{1,1},longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable);
                            [longwindTicker,longQuant,shortwindTicker,shortQuant] = obj.openPair(newStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable);
                            % ��͢��2020/06/04:����߼��ǲ����е����⣬���´�obj.currPairList{1,1}���������¼����pair��
                            % ���2020/06/05:����һֱ��ͬһ��λ�ñȽϰ�����������Ƚϵ�ȫ��������pair��û����pair��
                            % ���2020/06/06:������ÿ���ڱȽ�֮ǰ�����������򣬱�֤��С���ڵ�һ����
                       end
                    avaliableExpect(x,y) = 0;%���Ѿ��ȽϹ������ֵ��ֵΪ0����ֹ�´��ٴ�ѡ��
                    end    
                else
                    break;
                end

            end
            buyOrderList.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            buyOrderList.account = obj.accounts('stockAccount');
            buyOrderList.price = obj.orderPriceType;
            buyOrderList.assetCode = longwindTicker;
            buyOrderList.quantity = longQuant;

            sellOrderList.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
            sellOrderList.account = obj.accounts('stockAccount');
            sellOrderList.price = obj.orderPriceType;
            sellOrderList.assetCode = shortwindTicker;
            sellOrderList.quantity = shortQuant;

        end

        function orderSort(obj)
            len = length(obj.currPairList);
            for i = 1:len
                for j =1:len-i+1
                    if obj.currPairList{1,j}.expectReturn > obj.currPairList{1,j+1}.expectReturn
                         % ��͢��2020/06/04:�����������ð������ɣ������Ҳ��Ǻ�����currPairList{1,j}���õ���ɶ��������ƣ�Ӧ��ֻ��Ҫһ���±������
                         % ���2020/06/06:ϵͳĬ����һά������������һ����������һ����ϰ��������
                        tools = obj.currPairList{1,j+1};
                        obj.currPairList{1,j+1} = obj.currPairList{1,j};
                        obj.currPairList{1,j} = tools;
                    end
                end
            end
        end


        function  [longwindTicker,longQuant,shortwindTicker,shortQuant] = openPair(obj,newStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable)

            [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);
            windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(newStruct.stock1);
            windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(newStruct.stock2);%wind��Ʊ����

            fwdPrice1 = aggregatedDataStruct.stock.properties.fwd_close(dateLoc, newStruct.stock1);
            fwdPrice2 = aggregatedDataStruct.stock.properties.fwd_close(dateLoc, newStruct.stock2);%��Ȩ�۸����������ʽ����

            realPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, newStruct.stock1);
            realPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, newStruct.stock2);%����ʵ�ɼۼ۸�����������ʵͷ��
            % ��͢��2020/06/04:��һ������ô�ɣ����ǵ���δ�������ˡ�����close(dateLoc��newStruct.stock2)�� 
            % ���2020/06/06:�Ѿ��޸�

            everyCash = 0.85*cashAvailable/(10-length(currPairList));%ÿ��Ͷ�ʿ����ʽ�
            cashFor1 = (1*fwdPrice1)/(1*fwdPrice1+abs(newStruct.beta)*fwdPrice2)*everyCash;%������ʽ����
            cashFor2 = (abs(newStruct.beta)*fwdPrice2)/(1*fwdPrice1+abs(newStruct.beta)*fwdPrice2)*everyCash;

            costPrice1 = aggregatedDataStruct.stock.properties.open(dateLoc+1, newStruct.stock1);
            costPrice2 = aggregatedDataStruct.stock.properties.open(dateLoc+1, newStruct.stock2);%�õڶ���Ŀ��̼۸������㽻�׳ɱ�
            realstock1Position = floor(cashFor1/costPrice1/100)*100*newStruct.stock1Position;
            realstock2Position = floor(cashFor2/costPrice2/100)*100*newStruct.stock2Position;%������ɺ��ͷ��

            newStruct.stock1Position = floor(cashFor1/realPrice1/100)*100*newStruct.stock1Position;
            newStruct.stock2Position = floor(cashFor2/realPrice2/100)*100*newStruct.stock2Position;%����ͷ��
            % ��͢��2020/06/04:�ⲿ���漰��δ�����ݣ�����Ϊ����ָ���������� 
            % ���2020/06/06:�Ѿ��޸�


            newStruct.openCost = (abs(realstock1Position)*costPrice1+abs(realstock2Position)*costPrice2)*2/10000;%�������趨Ϊ���֮��
            % ��͢��2020/06/04:�ⲿ����Ȼ�漰��δ�����ݣ���������Ϊ����ָ����������Ϊ��¼�����ᳫ������������ 
            % ���2020/06/06:�Ѿ��޸�
            % ��͢��2020/06/05:�ⲿ���������ڵ��޸ķ�ʽ�Ͳ�����ʵ��openCost�ˣ�Ҫ�������ǰ��һ������open�ļ۸�Ҫ�����վ�����Ϊ0���ڵڶ��������
            % ���2020/06/06:�Ѿ��޸�Ϊ�ÿ��̼ۼ����cost




            if newStruct.stock1Position>0
                longwindTicker{length(longwindTicker)+1,1} = windTickers1;
                longQuant = [longQuant,newStruct.stock1Position];
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers1;
                shortQuant = [shortQuant,-newStruct.stock1Position]; %���ﶼҪ���������

            end

            if newStruct.stock2Position>0
                longwindTicker{length(longwindTicker)+1,1} = windTickers2;
                longQuant = [longQuant,newStruct.stock2Position];
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers2;
                shortQuant = [shortQuant,-newStruct.stock2Position];

            end

            obj.currPairList{1,length(currPairList)+1} = newStruct;
        end



        function  [longwindTicker,longQuant,shortwindTicker,shortQuant,cashAvailable] = closePair(obj,closeStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable)

             [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);
            if closeStruct.Pnl>closeStruct.opencost
                obj.winCounter= obj.winCounter+1;
            else
                obj.lossCounter= obj.lossCounter+1;
            end
            % ��͢��2020/06/05:ÿ��ƽ��ʱ��Ҫ��ƽ�ּ�����winCounter��lossCounter����+1���������жϾ���ƽ��ʱ���ڶ���������۸�����ڿ��ֳɱ����������滹����ʧ���˴���Ϊͳ��ʹ�ã��ʿ�ʹ��δ������
            % �ⲿ�ֿ��԰���ppt����ʾ���ģ�����һ��cell���󣬶���ÿ��ƽ��ʱ���洢ƽ�ֵĹ�Ʊ���������ڣ�ƽ�����ڣ�ƽ��ԭ�����Ϣ���������ж�������ݽ���ͳ�Ʒ�������ϸ����
            % ���2020/06/06:�Ѿ��޸ģ�ϸ�������ڿ�����Ҫ֮���ǰ�벿��ͬѧЭ�̹�ͬ���
            windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(closeStruct.stock1);
            windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(closeStruct.stock2);%�õ�wind��Ʊ����


            realPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, closeStruct.stock1);
            % ��͢��2020/06/05: dataLoc�ǳ�Ա�������޷�ֱ�ӷ��ʣ��봫�λ���������Ա������
            % ���2020/06/06: �Ѿ��޸�
            realPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, closeStruct.stock2);%��ʵ�۸��������������ֽ�

            cashAvailable = cashAvailable+abs(newStruct.stock1Position)*realPrice1+abs(newStruct.stock2Position)*realPrice2*(1-2/10000);%���ӿ����ֽ�
            % ��͢��2020/06/04:�ⲿ���漰��δ�����ݣ�����Ϊ����ָ����������
            % ���2020/06/06:�Ѿ��޸�
            obj.currPairList = obj.currPairList{2:end} ; %ɾ����һ��

            if closeStruct.stock1Position<0
                longwindTicker{length(longwindTicker)+1,1} = windTickers1;
                longQuant = [longQuant,0];%ƽ��ʱ��Ŀ���λ�趨Ϊ0
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers1;
                shortQuant = [shortQuant,0];
            end

            if closeStruct.stock2Position<0
                longwindTicker{length(longwindTicker)+1,1} = windTickers2;
                longQuant = [longQuant,0];
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers2;
                shortQuant = [shortQuant,0];
            end
        end
     end
end
