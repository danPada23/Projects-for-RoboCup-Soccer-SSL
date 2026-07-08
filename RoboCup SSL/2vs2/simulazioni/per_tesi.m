clear; 
clc; 
close all;
clear classes;

% ==========================================
% --- PARAMETRI GENERALI E SETUP ---
% ==========================================
X_max = 0.8; Y_max = 0.6; Ts = 0.01;
A = 0.025; b = 0.03; d = A * (sqrt(3)/2)+0.01; 
r_p = 0.02; m_p = 0.0027;

% --- VARIABILI TEMPO E MATCH ---
durata_tempo = 5*6; % 10 minuti in secondi (600) per ogni tempo
tempo_simulato = 0;
tempo_corrente = 1; % 1 = Primo tempo, 2 = Secondo tempo

% --- PARAMETRI ROBOT ---
m_r = 1.5; I_r = 0.5 * m_r * A^2; 
e = 0.8; 
Kp = 4.0; Ki = 0.5;        

% --- SETUP SOGLIE FSM E DISTANZE ---
N_pallini = 3.5; step_pallini = 0.05;
dist_base = Y_max/2;     
Delta = dist_base - b - d - (N_pallini * step_pallini);
R_min = 2 * Delta;
R_max = R_min + (2 * Delta); 
R_mid = (R_max + R_min) / 2; 
goal_width = 0.25; goal_depth = r_p + 0.03;

% --- SETUP COACH E RUOLI 2vs2 ---
reception_radius = 0.2; % Raggio di cattura e smarcamento del follower
behavior_Left = 'offense';  
behavior_Right = 'defense'; 

% --- VARIABILI PUNTEGGIO ---
score_L = 0; 
score_R = 0; 
stati_nomi = {'WAIT', 'PURSUE', 'BACK', 'CUSTOM', 'ACTION', 'ATTACCO', 'STOP', 'ESCAPE', 'SPAZZATA'};

% ==========================================
% --- INIZIALIZZAZIONE AMBIENTE E CAMPO ---
% ==========================================
lim_x = [0, X_max]; lim_y = [0, Y_max];
safe_x = [d, X_max - d]; safe_y = [d, Y_max - d];
campo = Field(lim_x, lim_y, safe_x, safe_y, goal_width, goal_depth);

% ==========================================
% --- SPAWN INIZIALE RANDOMIZZATO E SFASATO ---
% ==========================================
bot_L_start_x = campo.safe_x(1);
bot_R_start_x = campo.safe_x(2);

% Spawn asse Y sfasato per i due compagni di squadra (Alto e Basso)
start_y_up = Y_max * 0.75;
start_y_dw = Y_max * 0.25;

ball_start_y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));

if rand() > 0.5
    min_x = bot_L_start_x + R_mid;
    max_x = (X_max / 2) - 0.05; 
    ball_start_x = min_x + rand() * (max_x - min_x);
    disp('Calcio d''inizio: Palla nella metà campo SINISTRA');
else
    min_x = (X_max / 2) + 0.05;
    max_x = bot_R_start_x - R_mid;
    ball_start_x = min_x + rand() * (max_x - min_x);
    disp('Calcio d''inizio: Palla nella metà campo DESTRA');
end

% Creazione Oggetti Fisici (4 Bot + Palla)
palla = Ball(ball_start_x, ball_start_y, r_p, m_p);

bot_L1 = Bot(bot_L_start_x, start_y_up, 0, b, d, A, m_r, I_r, e, Kp, Ki); 
bot_L2 = Bot(bot_L_start_x, start_y_dw, 0, b, d, A, m_r, I_r, e, Kp, Ki); 

bot_R1 = Bot(bot_R_start_x, start_y_up, pi, b, d, A, m_r, I_r, e, Kp, Ki); 
bot_R2 = Bot(bot_R_start_x, start_y_dw, pi, b, d, A, m_r, I_r, e, Kp, Ki); 

% Creazione Cervelli (4 Planner)
planner_L1 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_L1.x, bot_L1.y, 1);
planner_L2 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_L2.x, bot_L2.y, 1);

planner_R1 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_R1.x, bot_R1.y, -1);
planner_R2 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_R2.x, bot_R2.y, -1);

% Creazione Coach e Assegnazione Ruoli Iniziali
coach_L = Coach('Team 1', reception_radius, behavior_Left);
coach_R = Coach('Team 2', reception_radius, behavior_Right);

coach_L.assign_initial_roles(planner_L1, planner_L2);
coach_R.assign_initial_roles(planner_R1, planner_R2);

% ==========================================
% --- SETUP GRAFICA ---
% ==========================================
% 1. Allarghiamo la finestra a 1000 pixel per creare spazio laterale
Scenario = figure('Name','Billiard Robot Simulator - 2vs2 Match', ...
    'NumberTitle','off', 'Position', [100, 100, 1000, 600]);

% 2. Fissiamo manualmente gli assi (il campo) a sinistra
ax = gca;
ax.Units = 'pixels';
ax.Position = [50, 50, 700, 500]; % [x_inizio, y_inizio, larghezza, altezza]

hold on; axis equal;
margine_camera = 0.08;
xlim([lim_x(1) - margine_camera, lim_x(2) + margine_camera]); 
ylim([lim_y(1) - margine_camera, lim_y(2) + margine_camera]);
disp('--- INIZIO PARTITA 2vs2 ---');
th_circ = linspace(0, 2*pi, 100);
circ_unit_x = cos(th_circ);
circ_unit_y = sin(th_circ);

% ==========================================
% --- UI INTERATTIVA: SLIDER TUNING ---
% ==========================================
nomi_tattiche = {'ULTRA DIFENSIVO', 'DIFENSIVO', 'EQUILIBRATO', 'OFFENSIVO', 'ULTRA OFFENSIVO'};
larghezza_ui = 200;

% 3. Spostiamo i controlli UI nello spazio vuoto a DESTRA
% (Il campo finisce a x=750, quindi mettiamo la UI a x=780)
x_ui = 780;

% --- 1. Tattica Squadra CIANO (Top) ---
txt_tactic_L = uicontrol('Style', 'text', 'Position', [x_ui, 320, larghezza_ui, 20], ...
    'String', sprintf('Tattica Team 1: %s', nomi_tattiche{coach_L.tattica}), ...
    'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', 'cyan');

sld_tactic_L = uicontrol('Style', 'slider', 'Min', 1, 'Max', 5, 'Value', coach_L.tattica, ...
    'Position', [x_ui, 300, larghezza_ui, 20], 'SliderStep', [0.25, 0.25], 'BackgroundColor', [0.5 0.5 0.5], ...
    'Callback', @(src, event) update_tactic(src, txt_tactic_L, coach_L, nomi_tattiche, 'Team 1'));

% --- 2. Stanchezza Squadra CIANO ---
txt_fatigue_L = uicontrol('Style', 'text', 'Position', [x_ui, 250, larghezza_ui, 20], ...
    'String', sprintf('Stanchezza Team 1: %d%%', round(coach_L.stanchezza * 100)), ...
    'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', 'cyan');

sld_fatigue_L = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', coach_L.stanchezza, ...
    'Position', [x_ui, 230, larghezza_ui, 20], 'BackgroundColor', [0.5 0.5 0.5], ...
    'Callback', @(src, event) update_stanchezza(src, txt_fatigue_L, coach_L, 'Team 1'));

% --- 3. Tattica Squadra ARANCIO ---
txt_tactic_R = uicontrol('Style', 'text', 'Position', [x_ui, 180, larghezza_ui, 20], ...
    'String', sprintf('Tattica Team 2: %s', nomi_tattiche{coach_R.tattica}), ...
    'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', [1 0.5 0]);

sld_tactic_R = uicontrol('Style', 'slider', 'Min', 1, 'Max', 5, 'Value', coach_R.tattica, ...
    'Position', [x_ui, 160, larghezza_ui, 20], 'SliderStep', [0.25, 0.25], 'BackgroundColor', [0.5 0.5 0.5], ...
    'Callback', @(src, event) update_tactic(src, txt_tactic_R, coach_R, nomi_tattiche, 'Team 2'));

% --- 4. Stanchezza Squadra ARANCIO ---
txt_fatigue_R = uicontrol('Style', 'text', 'Position', [x_ui, 110, larghezza_ui, 20], ...
    'String', sprintf('Stanchezza Team 2: %d%%', round(coach_R.stanchezza * 100)), ...
    'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', [1 0.5 0]);

sld_fatigue_R = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', coach_R.stanchezza, ...
    'Position', [x_ui, 90, larghezza_ui, 20], 'BackgroundColor', [0.5 0.5 0.5], ...
    'Callback', @(src, event) update_stanchezza(src, txt_fatigue_R, coach_R, 'Team 2'));

% --- 5. Raggio di Ricezione Globale (Bottom) ---
txt_radius = uicontrol('Style', 'text', 'Position', [x_ui, 40, larghezza_ui, 20], ...
    'String', sprintf('Reception Radius: %.2f', reception_radius), ...
    'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', 'white');

sld_radius = uicontrol('Style', 'slider', 'Min', 0.05, 'Max', 0.25, 'Value', reception_radius, ...
    'Position', [x_ui, 20, larghezza_ui, 20], 'SliderStep', [0.25, 0.25], 'BackgroundColor', [0.5 0.5 0.5], ...
    'Callback', @(src, event) update_radius(src, txt_radius, coach_L, coach_R, planner_L1, planner_L2, planner_R1, planner_R2));

% ==========================================
% --- LOOP PRINCIPALE ---
% ==========================================
while ishandle(Scenario)
    tempo_simulato = tempo_simulato + Ts;
    
    % 1. DEFINIZIONE SCHIERAMENTI
    enemies_L = [bot_R1, bot_R2];
    enemies_R = [bot_L1, bot_L2];

    % 2. AGGIORNAMENTO STRATEGIA (Il Coach valuta il Decision Tree e assegna i ruoli)
    coach_L.update_roles(bot_L1, bot_L2, planner_L1, planner_L2, palla, enemies_L, campo, X_max);
    coach_R.update_roles(bot_R1, bot_R2, planner_R1, planner_R2, palla, enemies_R, campo, X_max);
    
    % 3. I CERVELLI DECIDONO IN CONTEMPORANEA (FSM per Leader, Target per Follower)
    
    [u1_L1, u2_L1] = planner_L1.decide_action(bot_L1, bot_L2, planner_L2, enemies_L, palla, campo, X_max, Y_max, d);
    [u1_L2, u2_L2] = planner_L2.decide_action(bot_L2, bot_L1, planner_L1, enemies_L, palla, campo, X_max, Y_max, d);
    
    [u1_R1, u2_R1] = planner_R1.decide_action(bot_R1, bot_R2, planner_R2, enemies_R, palla, campo, X_max, Y_max, d);
    [u1_R2, u2_R2] = planner_R2.decide_action(bot_R2, bot_R1, planner_R1, enemies_R, palla, campo, X_max, Y_max, d);
    
    % 3. CINEMATICA E FISICA 
    bot_L1.linearize_and_move(u1_L1, u2_L1, Ts);
    bot_L2.linearize_and_move(u1_L2, u2_L2, Ts);
    bot_R1.linearize_and_move(u1_R1, u2_R1, Ts);
    bot_R2.linearize_and_move(u1_R2, u2_R2, Ts);
    
    % --- RISOLUZIONE COMPENETRAZIONE TRA BOT (Tutte le coppie possibili) ---
    all_bots = [bot_L1, bot_L2, bot_R1, bot_R2];
    for i = 1:4
        for j = (i+1):4
            campo.resolve_bot_bot_collision(all_bots(i), all_bots(j));
        end
    end
   
    % Dinamica Palla
    campo.apply_repulsion(palla, Ts);
    palla.update_dynamics(Ts);
    
    % Controllo Muri 
    for i = 1:4
        campo.check_bot_walls(all_bots(i));
    end
    
    % --- URTI BOT-PALLA ---
    % Mappatura stato FSM per la difesa (nerf cerchio attivo). Se il follower difende, passa 3
    get_eff_state = @(plan) (strcmp(plan.role, 'follower') && strcmp(plan.follower_state, 'defense')) * 3 + ...
                            (strcmp(plan.role, 'leader') || (strcmp(plan.role, 'follower') && ~strcmp(plan.follower_state, 'defense'))) * plan.fsm_state;

    campo.resolve_collision(bot_L1, palla, get_eff_state(planner_L1));
    campo.resolve_collision(bot_L2, palla, get_eff_state(planner_L2));
    campo.resolve_collision(bot_R1, palla, get_eff_state(planner_R1));
    campo.resolve_collision(bot_R2, palla, get_eff_state(planner_R2));
    
    goal_status = campo.check_ball_walls(palla);
    
    % 4. GESTIONE EVENTI (Gol e Aggiornamento Punteggio)
    if goal_status > 0
        drawnow; pause(1.0); 
        
        if goal_status == 1
            score_R = score_R + 1;
            fprintf('\n!!! GOL DELLA SQUADRA ARANCIO !!!\n');
        elseif goal_status == 2
            score_L = score_L + 1;
            fprintf('\n!!! GOL DELLA SQUADRA CIANO !!!\n');
        end
        fprintf('--- PUNTEGGIO ATTUALE: Ciano %d  |  Arancio %d ---\n\n', score_L, score_R);
        
        % Reset Posizioni Bot (Sfasate)
        bot_L1.x = campo.safe_x(1); bot_L1.y = start_y_up; bot_L1.theta = 0;
        bot_L2.x = campo.safe_x(1); bot_L2.y = start_y_dw; bot_L2.theta = 0;
        
        bot_R1.x = campo.safe_x(2); bot_R1.y = start_y_up; bot_R1.theta = pi;
        bot_R2.x = campo.safe_x(2); bot_R2.y = start_y_dw; bot_R2.theta = pi;
        
        for i=1:4
            all_bots(i).v = 0; all_bots(i).omega = 0; 
            all_bots(i).err_sum_x = 0; all_bots(i).err_sum_y = 0;
        end
        
        % Respawn Palla Random
        palla.y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));
        if goal_status == 1
            palla.x = (bot_L1.x + R_mid) + rand() * ((X_max/2 - 0.05) - (bot_L1.x + R_mid));
        elseif goal_status == 2
            palla.x = (X_max/2 + 0.05) + rand() * ((bot_R1.x - R_mid) - (X_max/2 + 0.05));
        end
        palla.vx = 0; palla.vy = 0; palla.theta = 0; 
        
        % Reset Planner e Ruoli Iniziali
        planner_L1.reset(); planner_L2.reset();
        planner_R1.reset(); planner_R2.reset();
        coach_L.assign_initial_roles(planner_L1, planner_L2);
        coach_R.assign_initial_roles(planner_R1, planner_R2);
        
        pause(0.5); 
    end
    
    % ==========================================
    % 5. DISEGNO GRAFICO
    % ==========================================
    cla;
    campo.draw();
    
    minuti = floor(tempo_simulato / 60);
    secondi = floor(mod(tempo_simulato, 60));
    title(sprintf('Partita 2vs2 | Tempo %d - %02d:%02d | Ciano %d - %d Arancio', ...
        tempo_corrente, minuti, secondi, score_L, score_R), 'FontSize', 14, 'FontWeight', 'bold');
    
    % --- DISEGNO RAGGIO DI RICEZIONE (ROSSO TRASPARENTE) ---
    % Giusto: Legge dinamicamente planner_L1.reception_radius
    if strcmp(planner_L1.role, 'follower')
        rad_L1 = planner_L1.reception_radius;
        fill(bot_L1.x + rad_L1*circ_unit_x, bot_L1.y + rad_L1*circ_unit_y, 'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    end
    if strcmp(planner_L2.role, 'follower')
        rad_L2 = planner_L2.reception_radius;
        fill(bot_L2.x + rad_L2*circ_unit_x, bot_L2.y + rad_L2*circ_unit_y, 'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    end
    if strcmp(planner_R1.role, 'follower')
        rad_R1 = planner_R1.reception_radius;
        fill(bot_R1.x + rad_R1*circ_unit_x, bot_R1.y + rad_R1*circ_unit_y, 'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    end
    if strcmp(planner_R2.role, 'follower')
        rad_R2 = planner_R2.reception_radius;
        fill(bot_R2.x + rad_R2*circ_unit_x, bot_R2.y + rad_R2*circ_unit_y, 'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    end
    
    % --- ETICHETTE DI STATO A SCHERMO ---
    if strcmp(planner_L1.role, 'leader')
        lbl_L1 = sprintf('L: %s', stati_nomi{planner_L1.fsm_state+1}); 
    else
        lbl_L1 = sprintf('F: %s', upper(planner_L1.follower_state)); 
    end
    
    if strcmp(planner_L2.role, 'leader')
        lbl_L2 = sprintf('L: %s', stati_nomi{planner_L2.fsm_state+1}); 
    else
        lbl_L2 = sprintf('F: %s', upper(planner_L2.follower_state)); 
    end
    
    if strcmp(planner_R1.role, 'leader')
        lbl_R1 = sprintf('L: %s', stati_nomi{planner_R1.fsm_state+1}); 
    else
        lbl_R1 = sprintf('F: %s', upper(planner_R1.follower_state)); 
    end
    
    if strcmp(planner_R2.role, 'leader')
        lbl_R2 = sprintf('L: %s', stati_nomi{planner_R2.fsm_state+1}); 
    else
        lbl_R2 = sprintf('F: %s', upper(planner_R2.follower_state)); 
    end
    
    % --- SQUADRA SINISTRA (CIANO) ---
    bot_L1.draw('inter'); bot_L2.draw('inter');
    text(bot_L1.x, bot_L1.y + 0.05, lbl_L1, 'Color', [0 0.5 0.5], 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    text(bot_L2.x, bot_L2.y + 0.05, lbl_L2, 'Color', [0 0.5 0.5], 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % --- SQUADRA DESTRA (ARANCIO) ---
    bot_R1.draw('milan'); bot_R2.draw('milan');
    text(bot_R1.x, bot_R1.y + 0.05, lbl_R1, 'Color', [1 0.5 0], 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    text(bot_R2.x, bot_R2.y + 0.05, lbl_R2, 'Color', [1 0.5 0], 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    palla.draw(Delta, false);
    drawnow;
    
    % ==========================================
    % 6. GESTIONE FINE TEMPO/PARTITA
    % ==========================================
    if tempo_simulato >= durata_tempo
        if tempo_corrente == 1
            disp(' '); disp('      TRIPLICE FISCHIO - FINE 1° TEMPO   '); pause(3);
            tempo_corrente = 2; tempo_simulato = 0;
            
            % Reset posizioni
            bot_L1.x = campo.safe_x(1); bot_L1.y = start_y_up; bot_L1.theta = 0;
            bot_L2.x = campo.safe_x(1); bot_L2.y = start_y_dw; bot_L2.theta = 0;
            bot_R1.x = campo.safe_x(2); bot_R1.y = start_y_up; bot_R1.theta = pi;
            bot_R2.x = campo.safe_x(2); bot_R2.y = start_y_dw; bot_R2.theta = pi;
            
            for i=1:4, all_bots(i).v = 0; all_bots(i).omega = 0; all_bots(i).err_sum_x = 0; all_bots(i).err_sum_y = 0; end
            palla.x = X_max / 2; palla.y = Y_max / 2; palla.vx = 0; palla.vy = 0; palla.theta = 0;
            
            planner_L1.reset(); planner_L2.reset(); planner_R1.reset(); planner_R2.reset();
            coach_L.assign_initial_roles(planner_L1, planner_L2);
            coach_R.assign_initial_roles(planner_R1, planner_R2);
            disp('--- INIZIO SECONDO TEMPO ---');
            
        elseif tempo_corrente == 2
            disp(' '); disp('      TRIPLICE FISCHIO - FINE PARTITA!   '); pause(5);
            tempo_corrente = 1; tempo_simulato = 0; score_L = 0; score_R = 0;
            
            bot_L1.x = campo.safe_x(1); bot_L1.y = start_y_up; bot_L1.theta = 0;
            bot_L2.x = campo.safe_x(1); bot_L2.y = start_y_dw; bot_L2.theta = 0;
            bot_R1.x = campo.safe_x(2); bot_R1.y = start_y_up; bot_R1.theta = pi;
            bot_R2.x = campo.safe_x(2); bot_R2.y = start_y_dw; bot_R2.theta = pi;
            
            for i=1:4, all_bots(i).v = 0; all_bots(i).omega = 0; all_bots(i).err_sum_x = 0; all_bots(i).err_sum_y = 0; end
            palla.x = X_max / 2; palla.y = Y_max / 2; palla.vx = 0; palla.vy = 0; palla.theta = 0;
            
            planner_L1.reset(); planner_L2.reset(); planner_R1.reset(); planner_R2.reset();
            coach_L.assign_initial_roles(planner_L1, planner_L2);
            coach_R.assign_initial_roles(planner_R1, planner_R2);
            disp('--- INIZIO NUOVA PARTITA ---');
        end
    end
    pause(Ts);
end

% ==========================================
% --- FUNZIONI CALLBACK UI ---
% ==========================================
% function update_radius(slider_obj, txt_obj, c_L, c_R, p_L1, p_L2, p_R1, p_R2)
%     % Legge il nuovo valore e arrotonda per sicurezza allo step di 0.05
%     val = round(slider_obj.Value / 0.05) * 0.05;
%     slider_obj.Value = val; % Forza la manopola a "scattare" in posizione
% 
%     % Aggiorna l'etichetta di testo a schermo
%     txt_obj.String = sprintf('Reception Radius: %.2f', val);
% 
%     % Inietta dinamicamente il valore nel cervello dei robot in tempo reale
%     c_L.reception_radius = val;
%     c_R.reception_radius = val;
%     p_L1.reception_radius = val;
%     p_L2.reception_radius = val;
%     p_R1.reception_radius = val;
%     p_R2.reception_radius = val;
% end


function update_tactic(slider_obj, txt_obj, coach_obj, nomi_tattiche, team_label)
    % Forza l'arrotondamento per agganciarsi ai numeri interi da 1 a 5
    val = round(slider_obj.Value);
    slider_obj.Value = val; 
    
    % Aggiorna l'etichetta a schermo con il nome della squadra
    txt_obj.String = sprintf('Tattica %s: %s', team_label, nomi_tattiche{val});
    
    % Inietta la tattica live nel Coach specifico (Ciano o Arancio)
    coach_obj.tattica = val;
end

function update_radius(slider_obj, txt_obj, c_L, c_R, p_L1, p_L2, p_R1, p_R2)
    % Legge il nuovo valore e arrotonda per sicurezza allo step di 0.05
    val = round(slider_obj.Value / 0.05) * 0.05;
    slider_obj.Value = val; 
    
    % Aggiorna l'etichetta
    txt_obj.String = sprintf('Reception Radius: %.2f', val);
    
    % Inietta dinamicamente il valore nel cervello dei robot in tempo reale
    c_L.reception_radius = val;
    c_R.reception_radius = val;
    p_L1.reception_radius = val;
    p_L2.reception_radius = val;
    p_R1.reception_radius = val;
    p_R2.reception_radius = val;
end

function update_stanchezza(slider_obj, txt_obj, coach_obj, team_label)
    val = slider_obj.Value;
    
    % Aggiorna l'etichetta mostrando la percentuale di stanchezza
    txt_obj.String = sprintf('Stanchezza %s: %d%%', team_label, round(val * 100));
    
    % Inietta la stanchezza live nel Coach
    coach_obj.stanchezza = val;
end