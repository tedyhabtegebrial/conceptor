randstate = 0;
randstate = randstate + 1;
randn('state', randstate);

resolution = 200;
aperture = 2;
veci = 160;
I = eye(2);

X = randn(2,4);
R = X * X' / size(X,2);
[UR SR URt] = svd(R);


%%

figure(1); clf;
set(gcf, 'WindowStyle','normal');
set(gcf,'Position', [800 200 800 800]);
plotcounter = 0;
for aperture = 1*[1 2 3]
    for b = 10 * [0.0 0.1 0.5]
        plotcounter = plotcounter + 1;
        subplot(3,3,plotcounter);
        
        SR = diag([10 b ]);
        R = UR * SR * UR';
        
        S = zeros(2,resolution);
        for i = 1:resolution
            S(:,i) = [cos(2*pi*i/resolution), sin(2*pi*i/resolution) ]';
        end
        
        % compute  C
        s = diag(SR);
        rootArgs = (aperture^2 * s - 4) ./ (4*aperture^2 * s);
        nonNegInds = (rootArgs >= 0);
        sC = zeros(2,1);
        sC(nonNegInds) = 0.5 + sqrt(rootArgs(nonNegInds));
        C = UR * diag(sC) * UR';
        CS = C * S;
        
        
        
        % compute c
         F = S ;
        engys = sum(((UR * diag(sqrt(diag(SR))))' * F).^2,1 )  / 2;
        
        rootArgs = (aperture^2 * engys - 4) ./ (4*aperture^2 * engys);
        nonNegInds = (rootArgs >= 0);
        c = zeros(1,200);
        c(1,nonNegInds) = 0.5 + sqrt(rootArgs(1,nonNegInds));
        Sc = S * diag(c);
        
        C2 = F * diag(c) * F' / norm(F(1,:))^2;
        % C2 = 2*F * diag(c) * F' / resolution; % is identical
        
        C2S = C2 * S;
        
        
        textsize = 24;
        hold on;
        line(S(1,:)', S(2,:)', ...
            'Color', 'k', 'LineWidth', 1);
        
        [X Y] = vecLine(UR(:,1));
        line(X, Y, 'Color', 'k', 'LineWidth', 1, 'LineStyle', '--');
        [X Y] = vecLine(-UR(:,1));
        line(X, Y, 'Color', 'k', 'LineWidth', 1, 'LineStyle', '--');
        [X Y] = vecLine(UR(:,2));
        line(X, Y, 'Color', 'k', 'LineWidth', 1, 'LineStyle', '--');
        [X Y] = vecLine(-UR(:,2));
        line(X, Y, 'Color', 'k', 'LineWidth', 1, 'LineStyle', '--');
        
        line(Sc(1,:)', Sc(2,:)', ...
            'Color', 0.7*[0.5 1 0.5], 'LineWidth',1.5);
        line(CS(1,:)', CS(2,:)', ...
            'Color', 0.95 * [.5 .5 1], 'LineWidth', 6);
        line(C2S(1,:)', C2S(2,:)', ...
            'Color', 'r', 'LineWidth', 2);
        
        hold off;
        set(gca, 'XLim',[-1 1], 'YLim', [-1 1], 'Box', 'on');
        if plotcounter ~= 7
            set(gca, 'XTick', [], 'YTick', []);
        end
        if plotcounter >= 7
            set(gca, 'XTick', [-1 0 1], 'FontSize',textsize);
        end
        if mod(plotcounter,3) == 1
            set(gca,  'YTick', [-1 0 1], 'FontSize',textsize);
        end
        if plotcounter < 4
            title(sprintf('$\sigma_2$ = %g', b),...
                 'FontSize',textsize);
        end
        if mod(plotcounter,3) == 1
            ylabel(sprintf('aperture = %g',aperture), ...
                'FontSize',textsize);
        end
        
    end
end
%%
