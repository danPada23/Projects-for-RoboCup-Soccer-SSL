clear; clc; close all;

% ==========================================
% 1. INIZIALIZZAZIONE
% ==========================================
stile_scelto = 'Simeone'; % Assicurati che corrisponda all'agente caricato
env = RobotBilliardEnv();
env.StileReward = stile_scelto;

disp(['Caricamento dell''agente: ', stile_scelto, '...']);
load('Agente_Simeone_pazzo.mat', 'agent');

% ==========================================
% 2. OPZIONI DI TEST (INFERENZA PURA)
% ==========================================
num_episodi = 100; % Numero di partite di test
max_steps = 300;   % Lunghezza massima episodio

% Creiamo le opzioni di simulazione
simOpts = rlSimulationOptions('MaxSteps', max_steps, 'NumSimulations', num_episodi);

% ==========================================
% 3. ESECUZIONE DEL TEST
% ==========================================
disp('Avvio test di validazione contro la FSM. Attendere...');
experiences = sim(env, agent, simOpts);

% ==========================================
% 4. ESTRAZIONE DATI
% ==========================================
reward_episodi = zeros(num_episodi, 1);
for i = 1:num_episodi
    % Sommiamo tutti i reward ottenuti nei singoli step dell'episodio
    reward_episodi(i) = sum(experiences(i).Reward.Data);
end

reward_medio = mean(reward_episodi);
dev_std = std(reward_episodi);

fprintf('\n=== RISULTATI TEST ===\n');
fprintf('Reward Medio: %.2f\n', reward_medio);
fprintf('Deviazione Standard: %.2f\n', dev_std);

% ==========================================
% 5. PLOT GRAFICO PER LA TESI
% ==========================================
figure('Name', 'Analisi Prestazionale Post-Addestramento', 'Color', 'w', 'Position', [100, 100, 800, 400]);
hold on; grid on;

% Plot dei singoli episodi
plot(1:num_episodi, reward_episodi, '-o', 'Color', [0.2 0.6 0.8], ...
    'MarkerFaceColor', [0.2 0.6 0.8], 'MarkerSize', 4, 'DisplayName', 'Reward Episodico');

% Linea della media
yline(reward_medio, 'r-', ['Media: ', num2str(reward_medio, '%.2f')], ...
    'LineWidth', 2, 'LabelHorizontalAlignment', 'left', 'DisplayName', 'Reward Medio Globale');

% Formattazione
title(['Test di Validazione Post-Addestramento: Agente ', stile_scelto, ' vs FSM']);
xlabel('Episodi di Test');
ylabel('Ricompensa Totale Accumulata');
legend('Location', 'best');
hold off;