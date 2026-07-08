%% Train per fase 0 nuovo
clear; clc; close all;

% 1. Inizializzazione dell'Ambiente
% (Assicurati che RobotBilliardEnv.m sia nella stessa cartella)
env = RobotBilliardEnv();

% Estrazione automatica delle dimensioni (7 input, 4 output)
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

% ==========================================
% 2. TOPOLOGIA DELLA RETE NEURALE (MLP)
% ==========================================
% Struttura Fully Connected a 2 layer nascosti (128x128)
layers = [
    featureInputLayer(obsInfo.Dimension(1), 'Name', 'state_input')
    
    fullyConnectedLayer(128, 'Name', 'HiddenLayer_1')
    reluLayer('Name', 'ReLU_1')
    
    fullyConnectedLayer(128, 'Name', 'HiddenLayer_2')
    reluLayer('Name', 'ReLU_2')
    
    % Layer finale: 4 neuroni lineari (nessuna funzione di attivazione qui,
    % perché i Q-values possono essere numeri reali sia positivi che negativi)
    fullyConnectedLayer(length(actInfo.Elements), 'Name', 'Q_values_output')
];

% Conversione in dlnetwork (formato moderno per il Deep Learning in MATLAB)
criticNet = dlnetwork(layers);

% Creazione del blocco Critico (Valutatore Vettoriale)
critic = rlVectorQValueFunction(criticNet, obsInfo, actInfo);

% ==========================================
% 3. CONFIGURAZIONE AGENTE DQN E MEMORIA
% ==========================================
agentOpts = rlDQNAgentOptions(...
    'SampleTime', 1, ...                 % Meglio 1 (step discreto) per ambienti SMDP
    'TargetUpdateFrequency', 150, ...    % CORRETTO: Diamo stabilità alla rete (aggiorna ogni 150 step)
    'ExperienceBufferLength', 100000, ... 
    'DiscountFactor', 0.99, ...          
    'MiniBatchSize', 128);               

% Impostazioni del Tasso di Apprendimento
agentOpts.CriticOptimizerOptions.LearnRate = 1e-3;
agentOpts.CriticOptimizerOptions.GradientThreshold = 1.0;

% Impostazioni della Policy di Esplorazione (Epsilon-Greedy)
agentOpts.EpsilonGreedyExploration.Epsilon = 1.0;       
agentOpts.EpsilonGreedyExploration.EpsilonMin = 0.05;
agentOpts.EpsilonGreedyExploration.EpsilonDecay = 0.0005; % CORRETTO: Esplora gradualmente per circa 6000 step

% Istanziazione finale dell'agente
agent = rlDQNAgent(critic, agentOpts);

% ==========================================
% 4. OPZIONI E AVVIO DELL'ADDESTRAMENTO
% ==========================================
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 2000, ...               % Numero massimo di partite da giocare
    'MaxStepsPerEpisode', 200, ...         % Numero massimo di mosse logiche per singola partita
    'ScoreAveragingWindowLength', 50, ...  % CORRETTO: Finestra mobile per calcolare la media
    'Verbose', false, ...
    'Plots', 'training-progress', ...      % Mostra il grafico in tempo reale
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', 8);               % Si ferma da solo se la media mobile supera 8

% --- AVVIO (Scommenta la riga sotto per far partire la simulazione) ---
disp('Avvio dell''addestramento DQN...');
trainingStats = train(agent, env, trainOpts);

% Salvataggio dell'agente addestrato
save('Fase0_nuovo.mat', 'agent');