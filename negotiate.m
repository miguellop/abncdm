function state = negotiate()
   
    load ('UF100i');
    qf = 1;
   
    options = dgmset('Swnk', swnk, ...
                    'Agents', uf , ...
                    'AgentType', 'quotas', ...
                    'MediationType', 'dgm1', ...
                    'Nag', 3, ...
                    'Ni', 100, ...
                    'Nsets', 1, ...
                    'Nexp', 1, ...
                    'SelectionThreshold', [], ...
                    'Generations', 100, ...
                    'PopulationSize', 20, ...
                    'Plot', 'on', ...
                    'PlotFcn', {@plotrewardsfcn,@plotwinnercounterfcn}, ...
                    'QuotaType', 'decay');
    
    state.AgentPriorities = ones(1,options.Nag)/options.Nag;
    state.Score = [];               %Votos emitidos sobre el hijo ganador
    state.Expectation = [];         %Agregaci�n de votos del hijo ganador
    state.Quota = options.PopulationSize*0.75;
    qo = state.Quota;
    state.PopulationSize = options.PopulationSize;
    state.MaxPopulationSize = options.PopulationSize;
    state.Results.x = [];
    state.Results.y = [];  
    options = dgmset(options, 'Quotas', ...
        round(qo+(qf-qo)*linspace(0,1,options.Generations)));
        %round(qf+(qo-qf)*(1-exp(2*(1-((1:options.Generations+1)-1)./(options.Generations))))./(1-exp(2))));
    pd = []; sw = []; nash = []; kalai = [];
    %%Bucle de Sets
    for i=1:options.Nsets
        CurrentAgents = '@(x) [';
        for k=1:options.Nag-1
            CurrentAgents = [CurrentAgents, ...
                'options.Agents{' num2str(i) ',' num2str(k) '}(x),'];
        end
        CurrentAgents = [CurrentAgents, ...
            'options.Agents{' num2str(i) ',' num2str(k+1) '}(x)]'];
        fprintf('\n\n%s\n', CurrentAgents);
        CurrentAgents = eval(CurrentAgents);
        
        %%Bucle de Experimentos por Set       
        for j=1:options.Nexp
            fprintf(' %i - ', j);
            
            %Bucle de Generaciones
            thisPopulation = creationfcn(options.PopulationSize,options.Ni);
            fval = CurrentAgents(thisPopulation);
            prevScore = zeros(1,options.Nag);
    
            for k=1:options.Generations
                score = votingfcn(fval,state.Quota,options.AgentType);
                expectation = aggregationfcn(score,state.AgentPriorities,options.MediationType);
                selection = selectionfcn(expectation,k,options.Generations);
                                
                state.Score(k,:) = score(selection,:) + prevScore;
                prevScore = state.Score(k,:);

                state.Expectation(k) = expectation(selection);
                
                thisPopulation = mutationfcn(thisPopulation(selection,:),state.PopulationSize);
                fval = CurrentAgents(thisPopulation);

                if strcmp(options.Plot,'on')
                    subplot(3,2,1);
                    plotrewardsfcn(options.Generations,fval(1,:),k);
                    subplot(3,2,2);
                    plotexpectationfcn(options.Generations,k,expectation(selection));
                    subplot(3,2,3);
                    plotcumscorefcn(options.Generations,k,prevScore);
                    subplot(3,2,4);
                    plotscorefcn(options.Generations,k,score(selection,:));
                    subplot(3,2,5);
                    if state.PopulationSize>state.MaxPopulationSize
                        state.MaxPopulationSize = state.PopulationSize;
                    end
                    plotquotafcn(options.Generations,state.MaxPopulationSize,k,state.Quota,state.PopulationSize);
                    subplot(3,2,6);
                    plotxfcn(thisPopulation(1,:),options.Ni);
                end
                switch options.QuotaType
                    case 'fixed'
                        state.Quota = state.PopulationSize*0.5;
                    case 'dynamic'
                        state = updatepopulationsizefcn(state,k);
                        state = updatequotafcn(state,k);
                    case 'decay'
                        state.Quota = options.Quotas(k);
                    case 'dynamicquota'
                        state = updatequotafcn(state,k);
                    case 'dynamicpopulationsize'
                        state = updatepopulationsizefcn(state,k);
                end
            end
            
            x(j,:) = thisPopulation(1,:);
            y(j,:) = fval(1,:);
        end
        
        state.Results.x = [state.Results.x;x];
        state.Results.y = [state.Results.y;y];
        pd = [pd; getparetoeval(y, options.Swnk{i,options.Nag}.fval) - y];
        sw = [sw; repmat(options.Swnk{i,options.Nag}.sw, options.Nexp, 1) - y];
        nash = [nash; repmat(options.Swnk{i,options.Nag}.nash, options.Nexp, 1) - y];
        kalai = [kalai; repmat(options.Swnk{i,options.Nag}.kalai, options.Nexp, 1) - y];
    end
    
    state.Results.pd = sqrt(sum(pd.^2, 2))*100;
    state.Results.sw = sqrt(sum(sw.^2, 2))*100;
    state.Results.nash = sqrt(sum(nash.^2, 2))*100;
    state.Results.kalai = sqrt(sum(kalai.^2, 2))*100;
    state.Results.stats = mean([state.Results.pd,...
                              state.Results.sw,...
                              state.Results.nash,...
                              state.Results.kalai]); 
end

function pd = getparetoeval(eval, fval)
    [nre, nce] = size(eval);
    [nrf, ncf] = size(fval);
    pd = [];
    for i=1:nre
        [x, ind] = min( sum((fval-repmat(eval(i,:),nrf,1)).^2, 2));
        pd = [pd; fval(ind, :)];
    end
end