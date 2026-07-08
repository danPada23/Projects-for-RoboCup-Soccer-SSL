%% fase 1 da solo
clear; clc; close all;

% ==========================================
% 1. INIZIALIZZAZIONE AMBIENTE
% ==========================================
% Usa il tuo RobotBilliardEnv aggiornato e perfetto
env = RobotBilliardEnv();
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

% ==========================================
% 2. CREAZIONE DELLA RETE NEURALE "VERGINE"
% ==========================================
disp('Creazione di un nuovo agente DQN partendo da zero...');

% Struttura Fully Connected a 2 layer nascosti (128x128)
layers = [
    featureInputLayer(obsInfo.Dimension(1), 'Name', 'state_input')
    fullyConnectedLayer(128, 'Name', 'HiddenLayer_1')
    reluLayer('Name', 'ReLU_1')
    fullyConnectedLayer(128, 'Name', 'HiddenLayer_2')
    reluLayer('Name', 'ReLU_2')
    fullyConnectedLayer(length(actInfo.Elements), 'Name', 'Q_values_output')
];

criticNet = dlnetwork(layers);
critic = rlVectorQValueFunction(criticNet, obsInfo, actInfo);

% ==========================================
% 3. CONFIGURAZIONE AGENTE DQN (Esplorazione Totale)
% ==========================================
agentOpts = rlDQNAgentOptions(...
    'SampleTime', 1, ...                 % CORRETTO: 1 step discreto (Logica SMDP)
    'TargetUpdateFrequency', 150, ...    % CORRETTO: 150 per la stabilità
    'ExperienceBufferLength', 100000, ... 
    'DiscountFactor', 0.99, ...          
    'MiniBatchSize', 128);               

% Learning Rate standard per una rete nuova
agentOpts.CriticOptimizerOptions.LearnRate = 1e-3;
agentOpts.CriticOptimizerOptions.GradientThreshold = 1.0;

% Esplorazione: Partiamo da 1.0 (100% mosse casuali) perché non sa nulla!
agentOpts.EpsilonGreedyExploration.Epsilon = 1.00;       
agentOpts.EpsilonGreedyExploration.EpsilonMin = 0.05;
agentOpts.EpsilonGreedyExploration.EpsilonDecay = 0.0005; % CORRETTO: Esplorazione lunga

agent = rlDQNAgent(critic, agentOpts);

% ==========================================
% 4. OPZIONI DI ADDESTRAMENTO
% ==========================================
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 3000, ...               
    'MaxStepsPerEpisode', 250, ...         
    'ScoreAveragingWindowLength', 50, ...  
    'Verbose', false, ...
    'Plots', 'training-progress', ...    
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', 6.5);             % CORRETTO: 6.5 è un target eccellente contro un nemico mobile

% ==========================================
% 5. AVVIO FASE 1 DA ZERO
% ==========================================
disp('Inizio Fase 1 (From Scratch): Addestramento contro il Wanderer...');
trainingStats = train(agent, env, trainOpts);

% ==========================================
% 6. SALVATAGGIO
% ==========================================
disp('Addestramento terminato. Salvataggio...');
save('Fase1_nuovo.mat', 'agent');
disp('Salvataggio completato con successo!');


%%% fase 1 da fase 0
% clear; clc; close all;
% 
% % ==========================================
% % 1. INIZIALIZZAZIONE AMBIENTE
% % ==========================================
% % Crea l'ambiente (Assicurati che dentro RobotBilliardEnv.m, 
% % nella funzione step(), tu abbia sbloccato u1_R e u2_R)
% env = RobotBilliardEnv();
% 
% % ==========================================
% % 2. CARICAMENTO DEL "CERVELLO" (TRANSFER LEARNING)
% % ==========================================
% disp('Caricamento dell''agente addestrato nella Fase 0...');
% % Usiamo il secondo parametro 'agent' per evitare di sporcare 
% % il workspace con le vecchie variabili salvate per sbaglio.
% load('TrainedDQNAgent_Fase0.mat', 'agent'); 
% 
% % ==========================================
% % 3. AGGIORNAMENTO PARAMETRI DI ESPLORAZIONE
% % ==========================================
% % L'agente sa già andare in porta, non serve che esplori al 100% a caso.
% % Lo facciamo partire con un 40% di mosse casuali per fargli 
% % "scoprire" come difendersi dall'avversario.
% 
% agent.AgentOptions.EpsilonGreedyExploration.Epsilon = 0.40;  
% agent.AgentOptions.EpsilonGreedyExploration.EpsilonMin = 0.05;
% agent.AgentOptions.EpsilonGreedyExploration.EpsilonDecay = 0.001;
% 
% % Abbassiamo leggermente il Learning Rate.
% agent.AgentOptions.CriticOptimizerOptions.LearnRate = 1e-4; 
% 
% % ==========================================
% % 4. OPZIONI DI ADDESTRAMENTO
% % ==========================================
% trainOpts = rlTrainingOptions(...
%     'MaxEpisodes', 2500, ...               % Aumentiamo gli episodi: il task è più complesso
%     'MaxStepsPerEpisode', 250, ...         
%     'ScoreAveragingWindowLength', 50, ...  % Sintassi R2024a
%     'Verbose', false, ...
%     'Plots', 'training-progress', ...    
%     'StopTrainingCriteria', 'AverageReward', ...
%     'StopTrainingValue', 6);               % Target abbassato a 6: vincere con un nemico è più duro
% 
% % ==========================================
% % 5. AVVIO FASE 1
% % ==========================================
% disp('Inizio Fase 1: Addestramento contro il Wanderer...');
% trainingStats = train(agent, env, trainOpts);
% 
% % ==========================================
% % 6. SALVATAGGIO SICURO
% % ==========================================
% disp('Addestramento terminato. Salvataggio del nuovo agente...');
% % Salviamo esplicitamente SOLO l'oggetto agent per mantenere il file pulito
% save('TrainedDQNAgent_Fase1.mat', 'agent');
% disp('Salvataggio completato con successo!');