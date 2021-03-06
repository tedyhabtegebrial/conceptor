%%%% demo: incremental loading of patterns into reservoir

% set figure window to 1 x 1 panels


set(0,'DefaultFigureWindowStyle','docked');

%%% Experiment basic setup
randstate = 1; newNets = 1; newSystemScalings = 1;
learnType = 2; % set to 1 if every new pattern is to be
% entirely loaded into "virgin" reservoir
% space (batch offline); set to 2 if new
% patterns exploit already existing pattern
% generation(batch offline); set to 3 if new
% patterns exploit already existing pattern
% generation (online adaptive using LMS);

%%% Setting system params
Netsize = 100; % network size
NetSR = 1.5; % spectral radius
NetinpScaling = 1.5; % scaling of pattern feeding weights
BiasScaling = 0.25; % size of bias


%%% incremental loading learning (batch offline)
washoutLength = 200;
learnLength = 1000;


%%% incremental loading learning (online adaptive)
adaptLength = 1500;
adaptRate = 0.02;
errPlotSmoothRate = 0.01; % between 0 and 1, smaller = more smoothing

%%% pattern readout learning
TychonovAlphaReadout = 0.001;

%%% C testing
testLength = 400;
testWashout = 400;

%%% plotting
nPlotSingVals = 100; % how many singular values are plotted
signalPlotLength = 20;

%%% Setting patterns
%patterns = [51 52 53 54 32 33]; aperture = 10;
%patterns = [1 2 9 11 12 1 2 9 44 39 40 13  34 16 17 36]; aperture = 1000;
%patterns = [1 3 9 11 12 14 35 19 8 18 37 ]; aperture = 1000;
%patterns = [1 3 9 11 12  ]; aperture = 1000;
%patterns = [39 40 41 42 43 1 37 44 45 46 2]; aperture = 10;
%patterns = [55 56 57 58 51 52 53 54 32 33 38 47 48 49 50 59]; 
patts = cell(1,16);
for i = 1:16
    patts{i} = @(n) sin(2 * pi * n / (sqrt(2)* 3 * 1.1^i));
end
pattperms = randperm(16);
%pattperms = 1:16;
aperture = 3;
%patterns = [51 52 53 54]; aperture = 10;

% 1 = sine10  2 = sine15  3 = sine20  4 = spike20
% 5 = spike10 6 = spike7  7 = 0   8 = 1
% 9 = rand4; 10 = rand5  11 = rand6 12 = rand7
% 13 = rand8 14 = sine10range01 15 = sine10rangept5pt9
% 16 = rand3 17 = rand9 18 = rand10 19 = 0.8 20 = sineroot27
% 21 = sineroot19 22 = sineroot50 23 = sineroot75
% 24 = sineroot10 25 = sineroot110 26 = sineroot75tenth
% 27 = sineroots20plus40  28 = sineroot75third
% 29 = sineroot243  30 = sineroot150  31 = sineroot200
% 32 = sine10pt587352723 33 = sine10pt10.387352723
% 34 = rand7  35 = sine12  36 = rand5  37 = sine11
% 38 = sine10pt17352723  39 = sine5 40 = sine6
% 41 = sine7 42 = sine8  43 = sine9 44 = sine12
% 45 = sine13  46 = sine14  47 = sine10.8342522
% 48 = sine11.8522311  49 = sine12.5223223  50 = sine13.1900453
% 51 = sine7.1900453  52 = sine7.9004531  53 = sine8.4900453
% 54 = sine9.1900453 55 = sine5.19004  56 = sine5.8045
% 57 = sine6.49004 58 = sine6.9004 59 = sine13.9004

%%% Initializations

randn('state', randstate);
rand('twister', randstate);
I = eye(Netsize);
Np = length(patts);

% Create raw weights
if newNets
    if Netsize <= 20
        Netconnectivity = 1;
    else
        Netconnectivity = 10/Netsize;
    end
    WRaw = generate_internal_weights(Netsize, Netconnectivity);
    WinRaw = randn(Netsize, 1);
    WbiasRaw = randn(Netsize, 1);
end

% Scale raw weights and initialize weights
if newSystemScalings
    W = NetSR * WRaw;
    Win = NetinpScaling * WinRaw;
    Wbias = BiasScaling * WbiasRaw;
end

% Set pattern handles
% pattHandles;



%% incremental learning


if learnType == 1
    patternCollectors = cell(1,Np);
    pPL = cell(1,Np);
    sizesCall = zeros(1,Np);
    Calls = cell(1,Np);
    sizesCap = zeros(1,Np);
    
    startxs = zeros(Netsize, Np);
    Call = zeros(Netsize, Netsize);
    D = zeros(Netsize, Netsize);
    nativeCs = cell(1,Np);
    for p = 1:Np
        patt = patts{pattperms(p)}; % current pattern generator
        
        % drive reservoir in "virgin" subspace with current pattern
        xOldCollector = zeros(Netsize, learnLength );
        pCollector = zeros(1, learnLength );
        x = zeros(Netsize, 1);
        G = I - Call;
        for n = 1:(washoutLength + learnLength)
            u = patt(n); % pattern input
            xOld = x;
            x =  G * tanh(W * x +  Win * u + Wbias);
            
            if n > washoutLength
                xOldCollector(:, n - washoutLength ) = xOld;
                pCollector(1, n - washoutLength) = u;
            end
        end
        patternCollectors{1,p} = pCollector;
        pPL{1,p} = pCollector(1,1:signalPlotLength);
        R = xOldCollector * xOldCollector' / (learnLength + 1);
        Cnative = R * inv(R + I);
        nativeCs{1,p} = Cnative;
        startxs(:,p) = x;
        
        % compute D increment
        Dtargs = Win*pCollector;
        F = NOT(Call);
        Dargs = xOldCollector ;
        Dinc = (pinv(Dargs * Dargs' / learnLength + ...
            aperture^(-2) * I) * Dargs * Dtargs' / learnLength)' ;
        
        % update D and Call
        D = D  + Dinc ;
        Cap = PHI(Cnative, aperture);
        Call = OR(Call, Cap);
        Calls{1,p} = Call;
        [Ux Sx Vx] = svd(Call);
        sizesCall(1,p) = mean(diag(Sx));
        [Ux Sx Vx] = svd(Cap);
        sizesCap(1,p) = mean(diag(Sx));
    end
    
elseif learnType == 2 % extension exploiting redundancies
    
    patternCollectors = cell(1,Np);
    pPL = cell(1,Np);
    sizesCall = zeros(1,Np);
    sizesCap = zeros(1,Np);
    Calls = cell(1,Np);
    
    startxs = zeros(Netsize, Np);
    Call = zeros(Netsize, Netsize);
    D = zeros(Netsize, Netsize);
    nativeCs = cell(1,Np);
    for p = 1:Np
        patt = patts{pattperms(p)}; % current pattern generator
        
        % drive reservoir with current pattern
        xOldCollector = zeros(Netsize, learnLength );
        pCollector = zeros(1, learnLength );
        x = zeros(Netsize, 1);
        for n = 1:(washoutLength + learnLength)
            u = patt(n); % pattern input
            xOld = x;
            x =  tanh(W * x +  Win * u + Wbias);
            
            if n > washoutLength
                xOldCollector(:, n - washoutLength ) = xOld;
                pCollector(1, n - washoutLength) = u;
            end
        end
        patternCollectors{1,p} = pCollector;
        pPL{1,p} = pCollector(1,1:signalPlotLength);
        R = xOldCollector * xOldCollector' / (learnLength + 1);
        Cnative = R * inv(R + I);
        nativeCs{1,p} = Cnative;
        startxs(:,p) = x;
        
        % compute D increment
        Dtargs = Win*pCollector - D * xOldCollector;
        F = NOT(Call);
        Dargs = F * xOldCollector ;
        Dinc = (pinv(Dargs * Dargs' / learnLength + ...
            aperture^(-2) * I) * Dargs * Dtargs' / learnLength)' ;
        
        % update D and Call
        D = D  + Dinc ;
        Cap = PHI(Cnative, aperture);
        Call = OR(Call, Cap);
        Calls{1,p} = Call;
        [Ux Sx Vx] = svd(Call);
        sizesCall(1,p) = mean(diag(Sx));
        [Ux Sx Vx] = svd(Cap);
        sizesCap(1,p) = mean(diag(Sx));
    end
    
elseif learnType == 3 %(online adaptive)
    errPL = zeros(Np, adaptLength);
    xAdaptPL = zeros(3,adaptLength,Np);
    
    patternCollectors = cell(1,Np);
    pPL = cell(1,Np);
    sizesCall = zeros(1,Np);
    sizesCap = zeros(1,Np);
    Calls = cell(1,Np);
    
    startxs = zeros(Netsize, Np);
    Call = zeros(Netsize, Netsize);
    D = zeros(Netsize, Netsize);
    nativeCs = cell(1,Np);
    
    
    
    for p = 1:Np
        patt = patts{pattperms(p)}; % current pattern generator
        xOldCollector = zeros(Netsize, adaptLength );
        pCollector = zeros(1, adaptLength );
        x = zeros(Netsize, 1);
        F = NOT(Call);
        err = 1; 
        for i = 1:washoutLength + adaptLength
            u = patt(i);
            xOld = x;
            x = tanh(W * x + Win * u + Wbias);
            if i > washoutLength
                xAdaptPL(:, i - washoutLength,p) = x(1:3,1);
                xOldCollector(:, i - washoutLength) = xOld;
                pCollector(1, i - washoutLength) = u;
                thisErr = mean((D*xOld - Win*u).^2);
                err = (1-errPlotSmoothRate) * err + ...
                    errPlotSmoothRate * thisErr;
                errPL(p,i - washoutLength) = err;
                D = D + adaptRate * ...
                    ((Win * u - D  *xOld)* xOld' - ...
                    aperture^(-1/2)*D ) * F ;
            end
        end
        pPL{1,p} = pCollector(1:signalPlotLength);
        R = xOldCollector * xOldCollector' / (adaptLength + 1);
        Cnative = R * inv(R + I);
        nativeCs{1,p} = Cnative;
        
        Cap = PHI(Cnative, aperture);
        
        startxs(:,p) = x;
        
        Call = OR(Call, Cap);
        Calls{1,p} = Call;
        
        [Ux Sx Vx] = svd(Call);
        sizesCall(1,p) = mean(diag(Sx));
        [Ux Sx Vx] = svd(Cap);
        sizesCap(1,p) = mean(diag(Sx));
    end
    
    
end


%% learn readouts

% drive network again with all patterns, each run shielded by corresponding
% C.
allTrainArgs = zeros(Netsize, Np * learnLength);
allTrainOuts = zeros(1, Np * learnLength);
for p = 1:Np
    patt = patts{pattperms(p)}; % current pattern generator
    C = PHI(nativeCs{1,p}, aperture);
    xCollector = zeros(Netsize, learnLength );
    pCollector = zeros(1, learnLength );
    x = startxs(:,p);
    for n = 1:(washoutLength + learnLength)
        u = patt(n); % pattern input
        x = C * tanh(W * x + Win * u + Wbias);
        %x = tanh(Wstar * x + Win * u + Wbias);
        
        if n > washoutLength
            xCollector(:, n - washoutLength ) = x;
            pCollector(1, n - washoutLength) = u;
        end
    end
    allTrainArgs(:, (p-1)*learnLength+1:p*learnLength) = ...
        xCollector;
    allTrainOuts(1, (p-1)*learnLength+1:p*learnLength) = ...
        pCollector;
end
Wout = (inv(allTrainArgs * allTrainArgs' + ...
    TychonovAlphaReadout * eye(Netsize)) ...
    * allTrainArgs * allTrainOuts')';
% training error
NRMSE_readout = nrmse(Wout*allTrainArgs, allTrainOuts);
disp(sprintf('NRMSE readout relearn: %g', NRMSE_readout));



% % test with C
x_TestPL = zeros(5, testLength, Np);
p_TestPL = zeros(1, testLength, Np);
for p = 1:Np
    C = PHI(nativeCs{1, p}, aperture);
    %x = startxs(:,p);
    x = randn(Netsize,1);
    for n = 1:testWashout + testLength
        x = C * tanh(W *  x + D * x + Wbias);
        if n > testWashout
            x_TestPL(:,n-testWashout,p) = x(1:5,1);
            p_TestPL(:,n-testWashout,p) = Wout * x;
        end
    end
end

%% plot
% optimally align C-reconstructed readouts with drivers for nice plots
test_pAligned_PL = cell(1,Np);
test_xAligned_PL = cell(1,Np);
NRMSEsAligned = zeros(1,Np);

for p = 1:Np
    intRate = 20;
    thisDriver = pPL{1,p};
    thisOut = p_TestPL(1,:,p);
    thisDriverInt = interp1((1:signalPlotLength)',thisDriver',...
        (1:(1/intRate):signalPlotLength)', 'spline')';
    thisOutInt = interp1((1:testLength)', thisOut',...
        (1:(1/intRate):testLength)', 'spline')';
    
    L = size(thisOutInt,2); M = size(thisDriverInt,2);
    phasematches = zeros(1,L - M);
    for phaseshift = 1:(L - M)
        phasematches(1,phaseshift) = ...
            norm(thisDriverInt - ...
            thisOutInt(1,phaseshift:phaseshift+M-1));
    end
    [maxVal maxInd] = max(-phasematches);
    test_pAligned_PL{1,p} = ...
        thisOutInt(1,maxInd:intRate:...
        (maxInd+intRate*signalPlotLength-1));
    coarseMaxInd = ceil(maxInd / intRate);
    test_xAligned_PL{1,p} = ...
        x_TestPL(:,coarseMaxInd:coarseMaxInd+signalPlotLength-1,p);
    NRMSEsAligned(1,p) = ...
        nrmse(test_pAligned_PL{1,p},pPL{1,p});
end
%%
% figure(1); clf;
% fs = 18; fstext = 18;
% % set(gcf,'DefaultAxesColorOrder',[0  0.4 0.65 0.8]'*[1 1 1]);
%  set(gcf, 'WindowStyle','normal');
% 
% set(gcf,'Position', [600 100 1000 800]);
% for p = 1:Np
%     if p <= 8
%         thispanel = (p-1)*4+2;
%     else
%         thispanel = (p-9)*4+4;
%     end
%     subplot(8,4,thispanel);
%     plot(test_pAligned_PL{1,p}, 'LineWidth',6,'Color',0.85*[1 1 1]); hold on;
%     plot(pPL{1,p},'k','LineWidth',1); 
%     rectangle('Position', [0.1,-0.95,7,0.7],'FaceColor','w',...
%         'LineWidth',1);
%      text(1,-0.6,num2str(NRMSEsAligned(1,p),2),...
%         'Color','k','FontSize',fstext, 'FontWeight', 'bold');
%     
%     hold off;
%     if p == 1 || p == 9
%         title('driver and y','FontSize',fs);
%     end
%     if p ~= Np && p ~= 8
%         set(gca, 'XTickLabel',[]);
%     end
%     set(gca, 'YLim',[-1,1], 'FontSize',fs, 'Box', 'on');
%     
%     
%     if p <= 8
%         thispanel = (p-1)*4+1;
%     else
%         thispanel = (p-9)*4+3;
%     end
%     subplot(8,4,thispanel);
%     Call = Calls{1, p};
%     [Ux Sx Vx] = svd(Call);
%     diagSx = diag(Sx);
%     hold on;
%     %area(diagSx(1:nPlotSingVals,1),'LineWidth',4,'Color',0.35*[1 1 1] );
%     area(diagSx(1:nPlotSingVals,1),'FaceColor', 0.7*[1 1 1]);
%     if p == 1
%     rectangle('Position', [1,0.02,28,0.4],'FaceColor','w',...
%         'LineWidth',1);
%     else
%         rectangle('Position', [1,0.02,28,0.4],'FaceColor','w',...
%         'LineWidth',1);
%     end
%     text(4,0.2,num2str(sizesCall(1,p),2), ...
%         'Color','k','FontSize',fstext, 'FontWeight', 'bold');
%     rectangle('Position', [57,0.4,35,0.4],'FaceColor','w',...
%         'LineWidth',1);
%      text(60,0.6,['j = ', num2str(p)],...
%         'Color','k','FontSize',fstext, 'FontWeight', 'bold');
% %     rectangle('Position', [50,0.02,28,0.4],'FaceColor','w',...
% %         'LineWidth',1);
% %     text(52,0.2,num2str(sum(sizesCap(1,1:p)),2),...
% %         'Color','k','FontSize',fstext, 'FontWeight', 'bold');
%     hold off;
%     if p ~= Np && p ~= 8
%         set(gca,'YLim',[0,1], 'Ytick', [0 1], ...
%             'XLim', [0,nPlotSingVals], 'Xtick', [],'FontSize',fs);
%     else
%         set(gca,'YLim',[0,1], 'Ytick', [0 1], ...
%             'XLim', [0,nPlotSingVals], 'FontSize',fs);
%     end
%     set(gca, 'Box', 'on');
%     if p == 1 || p == 9
%         title('used space','FontSize',fs);
%     end
% end

%%
figure(1); clf;
fs = 16; fstext = 16;
% set(gcf,'DefaultAxesColorOrder',[0  0.4 0.65 0.8]'*[1 1 1]);
 set(gcf, 'WindowStyle','normal');

set(gcf,'Position', [100 100 1500 600]);
for p = 1:Np
    if p <= 8
        thispanel = (p-1)*2+1;
    else
        thispanel = (p-9)*2+2;
    end
    subplot(4,4,p);
    Call = Calls{1, p};
    [Ux Sx Vx] = svd(Call);
    diagSx = diag(Sx);
    
    hold on;
    
    area(2*diagSx(1:nPlotSingVals,1)-1,-1,'FaceColor', 1*[1 .6 .6]);
    
    
    plot(5:5:100, test_pAligned_PL{1,p}, ...
        'LineWidth',10,'Color', 1*[.5 1 .5]); hold on;
    plot(5:5:100, pPL{1,p},'k','LineWidth',2); 
    rectangle('Position', [72,-0.85,24,0.5],'FaceColor','w',...
        'LineWidth',1);
     text(73,-0.6,num2str(NRMSEsAligned(1,p),2),...
        'Color','k','FontSize',fstext, 'FontWeight', 'bold');



rectangle('Position', [72,0.35,25,0.5],'FaceColor','w',...
        'LineWidth',1);
     text(75,0.65,['j = ', num2str(p)],...
        'Color','k','FontSize',fstext, 'FontWeight', 'bold');
    
    
        rectangle('Position', [3,-0.85,20,0.5],'FaceColor','w',...
        'LineWidth',1);
    
    text(6,-0.6,num2str(sizesCall(1,p),2), ...
        'Color','k','FontSize',fstext, 'FontWeight', 'bold');
    
    hold off;
    
    if p <= 12
        set(gca, 'XTickLabel',[]);
    else
        set(gca, 'Xtick', [1,50,100], 'XTickLabel',[{'1'}, {'10'}, {'20'}]);
    end
    if not(p == 1 | p == 5 | p == 9 | p == 13)
        set(gca, 'YTickLabel', []);
    end
    set(gca, 'YLim',[-1,1], 'XLim', [1 100],'FontSize',fs, 'Box', 'on');
    
  
end

%%
if learnType == 3
    figure(2); clf;
    for p = 1:Np
        subplot(Np,1,p);
        plot(log10(errPL(p,:)));
        if p == 1
            title('log10 se');
        end
    end
end
