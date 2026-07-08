clear; clc; close all;

% ==========================================
% --- PANNELLO DI CONTROLLO: SCEGLI LO STILE ---
% ==========================================
% Opzioni valide: 'Standard', 'Continuo', 'Discreto', 'Striker',
% 'Defender', 'Simeone', 'Zeman','Catenaccio_Totale'
stile_scelto = 'Simeone';

fprintf('=== AVVIO ADDESTRAMENTO: STILE %s ===\n\n', upper(stile_scelto));

% ==========================================
% 1. INIZIALIZZAZIONE AMBIENTE
% ==========================================
env = RobotBilliardEnv(); 
env.StileReward = stile_scelto; % Comunichiamo la scelta al Wrapper!

% ==========================================
% 2. CARICAMENTO DELLA BASE (FASE 1)
% ==========================================
disp('Caricamento dell''agente base (Fase 1)...');
load('Agente_Simeone_pazzo.mat', 'agent'); 

% ==========================================
% 3. AGGIORNAMENTO PARAMETRI DI ESPLORAZIONE
% ==========================================
agent.AgentOptions.EpsilonGreedyExploration.Epsilon = 0.40;  
agent.AgentOptions.EpsilonGreedyExploration.EpsilonMin = 0.05;
agent.AgentOptions.EpsilonGreedyExploration.EpsilonDecay = 0.0001; 

agent.AgentOptions.CriticOptimizerOptions.LearnRate = 1e-4; 
agent.AgentOptions.CriticOptimizerOptions.GradientThreshold = 1.0;

% ==========================================
% 4. IMPOSTAZIONE DINAMICA DEL TARGET REWARD
% ==========================================
switch stile_scelto
    case 'Standard'
        target_reward = 4.5; % 80% win rate è sufficiente
    case 'Continuo'
        target_reward = 4.5;
    case 'Discreto'
        target_reward = 4.5;
    case 'Striker'
        target_reward = 5.0; % Più alto, ma non irraggiungibile
    case 'Defender'
        target_reward = 3.5; % Punterà a non prenderle
    case 'Simeone'
        target_reward = 8;
    case 'Zeman'
        target_reward = 4.5; 
    case 'Catenaccio_Totale'
        target_reward = 8; % Basato sull'accumulo di step positivi
end

% ==========================================
% 5. OPZIONI DI ADDESTRAMENTO
% ==========================================
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 3000, ...               
    'MaxStepsPerEpisode', 300, ...         
    'ScoreAveragingWindowLength', 100, ... 
    'Verbose', false, ...
    'Plots', 'training-progress', ...    
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', target_reward);   % Usa il target dinamico

% ==========================================
% 6. AVVIO FASE 2
% ==========================================
disp(['Inizio addestramento contro FSM. Traguardo (Average Reward) impostato a: ', num2str(target_reward)]);
trainingStats = train(agent, env, trainOpts);

% ==========================================
% 7. SALVATAGGIO DINAMICO
% ==========================================
nome_file = sprintf('Agente_%s_pazzo.mat', stile_scelto);
disp(['Addestramento terminato. Salvataggio in corso: ', nome_file]);
save(nome_file, 'agent');
disp('Salvataggio completato con successo!');


%----------------------------------------------------------------------------------------------%

% clear; clc; close all;
% 
% % ==========================================
% % 1. INIZIALIZZAZIONE AMBIENTE
% % ==========================================
% env = RobotBilliardEnv(); % Carica il nuovo wrapper con la FSM nemica
% 
% % ==========================================
% % 2. CARICAMENTO DEL "CERVELLO" (TRANSFER LEARNING)
% % ==========================================
% disp('Caricamento dell''agente addestrato contro il Wanderer (Fase 1)...');
% % Sostituisci il nome del file se lo avevi salvato diversamente
% load('TrainedDQNAgent_Fase1_FromScratch.mat', 'agent'); 
% 
% % ==========================================
% % 3. AGGIORNAMENTO PARAMETRI DI ESPLORAZIONE
% % ==========================================
% % L'agente sa già come segnare e schivare bot casuali. 
% % Ora deve capire come affrontare un bot "intelligente". 
% % Diamo un Epsilon del 40% (0.40) per farlo sperimentare senza azzerare la sua abilità.
% agent.AgentOptions.EpsilonGreedyExploration.Epsilon = 0.40;  
% agent.AgentOptions.EpsilonGreedyExploration.EpsilonMin = 0.05;
% agent.AgentOptions.EpsilonGreedyExploration.EpsilonDecay = 0.001; % Decadimento lento
% 
% % Abbassiamo il Learning Rate (Fine-tuning) per evitare instabilità
% agent.AgentOptions.CriticOptimizerOptions.LearnRate = 1e-4; 
% agent.AgentOptions.CriticOptimizerOptions.GradientThreshold = 1.0;
% 
% % ==========================================
% % 4. OPZIONI DI ADDESTRAMENTO
% % ==========================================
% trainOpts = rlTrainingOptions(...
%     'MaxEpisodes', 3000, ...               
%     'MaxStepsPerEpisode', 300, ...         % Aumentato: contro la FSM gli scambi potrebbero durare di più
%     'ScoreAveragingWindowLength', 100, ... 
%     'Verbose', false, ...
%     'Plots', 'training-progress', ...    
%     'StopTrainingCriteria', 'AverageReward', ...
%     'StopTrainingValue', 6.0);             % Target a 6: battere regolarmente la FSM è dura, ci saranno molti pareggi o sconfitte all'inizio
% 
% % ==========================================
% % 5. AVVIO FASE 2
% % ==========================================
% disp('Inizio Fase 2: IA vs FSM...');
% trainingStats = train(agent, env, trainOpts);
% 
% % ==========================================
% % 6. SALVATAGGIO
% % ==========================================
% disp('Addestramento terminato. Salvataggio dell''Agente Esperto...');
% save('TrainedDQNAgent_Fase2.mat', 'agent');
% disp('Salvataggio completato con successo!');