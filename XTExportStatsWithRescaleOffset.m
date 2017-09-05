function XTExportStatsWithOffset(aImarisApplicationID)

% Parameters
offset = 0.1;

% connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end


vFileNameString = vImarisApplication.GetCurrentFileName; % returns ‘C:/Imaris/Images/retina.ims’
vFileName = char(vFileNameString);
[vOldFolder, vName, vExt] = fileparts(vFileName); % returns [‘C:/Imaris/Images/’, ‘retina’, ‘.ims’]
vNewFileName = fullfile('g:/BitplaneBatchOutput', [vName, vExt]); % returns ‘c:/BitplaneBatchOutput/retina.ims’

scaleFactorFile = [ vFileName(1:end-4) '.scaleFactors.txt' ];
if exist(scaleFactorFile,'file')
    s = importdata(scaleFactorFile);
    scalef = s.data;
else
    scalef = [];
end

%%%%%% Export all stats for surfaces starting with TCR
saveTable(vImarisApplication, vNewFileName, offset, scalef);
saveTable(vImarisApplication, vNewFileName, 0, scalef);

end

function saveTable(vImarisApplication, vNewFileName, offset, scalef)

surpassObjects = xtgetsporfaces(vImarisApplication);
names = {surpassObjects.Name};

for vv = 1:length(surpassObjects)
    xObject = surpassObjects(vv).ImarisObject;

    statStruct = xtgetstats(vImarisApplication, xObject, 'ID', 'ReturnUnits', 1);
    
    statNames = {statStruct.Name};
    
    filename = [vNewFileName(1:end-4) ' - ' names{vv} ' - offset' num2str(offset) '.csv'];
    
    fd = fopen(filename,'w');
    %t = table;
    
    allstats = {'Intensity Mean','Intensity Min','Volume','Position'};
    
    headers = {};
    data = {double(statStruct(1).Ids)};
    
    for statn = 1:length(allstats)
        pat = allstats{statn};
        
        % Save Intensity Mean
        imeans = find(cellfun(@(x) ~isempty(strfind(x,pat)),statNames));

        for i = 1:length(imeans)
            imean = imeans(i);

             sname = statNames{imean};
            
            [startIndex, endIndex, tokIndex, matchStr, tokenStr, exprNames, splitStr] = regexp(sname,'Channel (?<ChNo>[0-9]+)');
            
            scalef_i = 1;
            if ~isempty(startIndex) 
                chNo = str2double(exprNames.ChNo);
                
                scalef_i = scalef(chNo)*.001;
                
                chanName = char(vImarisApplication.GetDataSet.GetChannelName(chNo-1));
                
                sname = [sname(1:startIndex-1) chanName];
            end
            
            headers{end+1} = sname;
            
            data{end+1} = statStruct(imean).Values/scalef_i+offset;

            %t.(statNames{imean})=v;
        end
    end
    
    headerString = sprintf('%s,',headers{:});
    headerString = ['ID,' headerString(1:end-1)];
    
    fprintf(fd,'%s\n',headerString);
    fprintf(fd,[repmat('%f,',1,numel(data)-1) '%f\n'],cat(2,data{:})');
    
    fclose(fd);
end

end
