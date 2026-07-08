clear; 
clc; 
close all;
clear classes;

% ==========================================
% --- INPUT UTENTE: CONFIGURAZIONE TORNEO ---
% ==========================================
nomi_tattiche = {'ULTRA DIFENSIVO', 'DIFENSIVO', 'EQUILIBRATO', 'OFFENSIVO', 'ULTRA OFFENSIVO'};

tattica_L = 3;
stanch_L  = 50 / 100;

tattica_R = 3;
stanch_R  = 0 / 100;

rec_rad   = 0.15;
num_partite = 10;

disp(' ');
disp('====================================================');
fprintf('INIZIO TORNEO: %d PARTITE\n', num_partite);
fprintf('Team 1: %s | Stanchezza: %d%%\n', nomi_tattiche{tattica_L}, round(stanch_L*100));
fprintf('Team 2: %s | Stanchezza: %d%%\n', nomi_tattiche{tattica_R}, round(stanch_R*100));
disp('====================================================');
disp(' ');

% Variabili per la Classifica Finale
punti_L = 0; punti_R = 0;
vittorie_L = 0; pareggi = 0; vittorie_R = 0;
gol_fatti_tot_L = 0; gol_fatti_tot_R = 0;
gol_subiti_tot_L = 0; gol_subiti_tot_R = 0;
autogol_tot_L = 0; autogol_tot_R = 0;

% ==========================================
% --- PARAMETRI FISICI GLOBALI ---
% ==========================================
X_max = 0.8; Y_max = 0.6; Ts = 0.01;
A = 0.025; b = 0.03; d = A * (sqrt(3)/2)+0.01; 
r_p = 0.02; m_p = 0.0027;
m_r = 1.5; I_r = 0.5 * m_r * A^2; 
e = 0.8; 
Kp = 4.0; Ki = 0.5;        

N_pallini = 3.5; step_pallini = 0.05;
dist_base = Y_max/2;     
Delta = dist_base - b - d - (N_pallini * step_pallini);
R_min = 2 * Delta; R_max = R_min + (2 * Delta); R_mid = (R_max + R_min) / 2; 
goal_width = 0.25; goal_depth = r_p + 0.03;

lim_x = [0, X_max]; lim_y = [0, Y_max];
safe_x = [d, X_max - d]; safe_y = [d, Y_max - d];

durata_tempo = 60; % 10 minuti in secondi per tempo (1200 sec totali a partita)

% ==========================================
% --- LOOP DEL TORNEO ---
% ==========================================
for partita = 1:num_partite
    
    % Inizializzazione Ambiente
    campo = Field(lim_x, lim_y, safe_x, safe_y, goal_width, goal_depth);
    
    bot_L_start_x = campo.safe_x(1); bot_R_start_x = campo.safe_x(2);
    start_y_up = Y_max * 0.75; start_y_dw = Y_max * 0.25;
    
    % Spawn iniziale randomizzato
    ball_start_y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));
    if rand() > 0.5
        ball_start_x = (bot_L_start_x + R_mid) + rand() * ((X_max/2 - 0.05) - (bot_L_start_x + R_mid));
    else
        ball_start_x = (X_max/2 + 0.05) + rand() * ((bot_R_start_x - R_mid) - (X_max/2 + 0.05));
    end
    
    palla = Ball(ball_start_x, ball_start_y, r_p, m_p);
    bot_L1 = Bot(bot_L_start_x, start_y_up, 0, b, d, A, m_r, I_r, e, Kp, Ki); 
    bot_L2 = Bot(bot_L_start_x, start_y_dw, 0, b, d, A, m_r, I_r, e, Kp, Ki); 
    bot_R1 = Bot(bot_R_start_x, start_y_up, pi, b, d, A, m_r, I_r, e, Kp, Ki); 
    bot_R2 = Bot(bot_R_start_x, start_y_dw, pi, b, d, A, m_r, I_r, e, Kp, Ki); 
    
    planner_L1 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_L1.x, bot_L1.y, 1);
    planner_L2 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_L2.x, bot_L2.y, 1);
    planner_R1 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_R1.x, bot_R1.y, -1);
    planner_R2 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_R2.x, bot_R2.y, -1);
    
    % Setup Coach
    coach_L = Coach('Team 1', rec_rad, 'offense');
    coach_R = Coach('Team 2', rec_rad, 'defense');
    
    coach_L.tattica = tattica_L; coach_L.stanchezza = stanch_L;
    coach_R.tattica = tattica_R; coach_R.stanchezza = stanch_R;
    
    planner_L1.reception_radius = rec_rad; planner_L2.reception_radius = rec_rad;
    planner_R1.reception_radius = rec_rad; planner_R2.reception_radius = rec_rad;
    
    coach_L.assign_initial_roles(planner_L1, planner_L2);
    coach_R.assign_initial_roles(planner_R1, planner_R2);
    
    % Statistiche di questo match
    score_L = 0; score_R = 0;
    autogol_L = 0; autogol_R = 0;
    tempo_simulato = 0;
    tempo_corrente = 1;
    
    % --- LOOP DELLA SINGOLA PARTITA ---
    while tempo_corrente <= 2
        tempo_simulato = tempo_simulato + Ts;
        
        enemies_L = [bot_R1, bot_R2];
        enemies_R = [bot_L1, bot_L2];
        
        coach_L.update_roles(bot_L1, bot_L2, planner_L1, planner_L2, palla, enemies_L, campo, X_max);
        coach_R.update_roles(bot_R1, bot_R2, planner_R1, planner_R2, palla, enemies_R, campo, X_max);
        
        [u1_L1, u2_L1] = planner_L1.decide_action(bot_L1, bot_L2, planner_L2, enemies_L, palla, campo, X_max, Y_max, d);
        [u1_L2, u2_L2] = planner_L2.decide_action(bot_L2, bot_L1, planner_L1, enemies_L, palla, campo, X_max, Y_max, d);
        
        [u1_R1, u2_R1] = planner_R1.decide_action(bot_R1, bot_R2, planner_R2, enemies_R, palla, campo, X_max, Y_max, d);
        [u1_R2, u2_R2] = planner_R2.decide_action(bot_R2, bot_R1, planner_R1, enemies_R, palla, campo, X_max, Y_max, d);
        
        bot_L1.linearize_and_move(u1_L1, u2_L1, Ts);
        bot_L2.linearize_and_move(u1_L2, u2_L2, Ts);
        bot_R1.linearize_and_move(u1_R1, u2_R1, Ts);
        bot_R2.linearize_and_move(u1_R2, u2_R2, Ts);
        
        all_bots = [bot_L1, bot_L2, bot_R1, bot_R2];
        for i = 1:4
            for j = (i+1):4
                campo.resolve_bot_bot_collision(all_bots(i), all_bots(j));
            end
        end
        
        campo.apply_repulsion(palla, Ts);
        palla.update_dynamics(Ts);
        
        for i = 1:4
            campo.check_bot_walls(all_bots(i));
        end
        
        get_eff_state = @(plan) (strcmp(plan.role, 'follower') && strcmp(plan.follower_state, 'defense')) * 3 + ...
                                (strcmp(plan.role, 'leader') || (strcmp(plan.role, 'follower') && ~strcmp(plan.follower_state, 'defense'))) * plan.fsm_state;
        
        campo.resolve_collision(bot_L1, palla, get_eff_state(planner_L1), 'L');
        campo.resolve_collision(bot_L2, palla, get_eff_state(planner_L2), 'L');
        campo.resolve_collision(bot_R1, palla, get_eff_state(planner_R1), 'R');
        campo.resolve_collision(bot_R2, palla, get_eff_state(planner_R2), 'R');
        
        goal_status = campo.check_ball_walls(palla);
        
        % Gestione Gol e Autogol
        if goal_status > 0
            if goal_status == 1
                score_R = score_R + 1;
                if strcmp(palla.last_touch, 'L')
                    autogol_L = autogol_L + 1;
                end
            elseif goal_status == 2
                score_L = score_L + 1;
                if strcmp(palla.last_touch, 'R')
                    autogol_R = autogol_R + 1;
                end
            end
            
            % Reset Posizioni
            bot_L1.x = campo.safe_x(1); bot_L1.y = start_y_up; bot_L1.theta = 0;
            bot_L2.x = campo.safe_x(1); bot_L2.y = start_y_dw; bot_L2.theta = 0;
            bot_R1.x = campo.safe_x(2); bot_R1.y = start_y_up; bot_R1.theta = pi;
            bot_R2.x = campo.safe_x(2); bot_R2.y = start_y_dw; bot_R2.theta = pi;
            
            for i=1:4, all_bots(i).v = 0; all_bots(i).omega = 0; all_bots(i).err_sum_x = 0; all_bots(i).err_sum_y = 0; end
            
            % Respawn palla dopo il gol a favore di chi ha subito
            palla.y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));
            if goal_status == 1
                palla.x = (bot_L1.x + R_mid) + rand() * ((X_max/2 - 0.05) - (bot_L1.x + R_mid));
            elseif goal_status == 2
                palla.x = (X_max/2 + 0.05) + rand() * ((bot_R1.x - R_mid) - (X_max/2 + 0.05));
            end
            palla.vx = 0; palla.vy = 0; palla.theta = 0; palla.last_touch = 'none';
            
            planner_L1.reset(); planner_L2.reset(); planner_R1.reset(); planner_R2.reset();
            coach_L.assign_initial_roles(planner_L1, planner_L2); coach_R.assign_initial_roles(planner_R1, planner_R2);
        end
        
        % Gestione Fine Primo Tempo
        if tempo_simulato >= durata_tempo
            tempo_corrente = tempo_corrente + 1;
            tempo_simulato = 0;
            
            bot_L1.x = campo.safe_x(1); bot_L1.y = start_y_up; bot_L1.theta = 0;
            bot_L2.x = campo.safe_x(1); bot_L2.y = start_y_dw; bot_L2.theta = 0;
            bot_R1.x = campo.safe_x(2); bot_R1.y = start_y_up; bot_R1.theta = pi;
            bot_R2.x = campo.safe_x(2); bot_R2.y = start_y_dw; bot_R2.theta = pi;
            for i=1:4, all_bots(i).v = 0; all_bots(i).omega = 0; all_bots(i).err_sum_x = 0; all_bots(i).err_sum_y = 0; end
            
            if tempo_corrente == 2
                palla.y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));
                if rand() > 0.5
                    palla.x = (bot_L1.x + R_mid) + rand() * ((X_max/2 - 0.05) - (bot_L1.x + R_mid));
                else
                    palla.x = (X_max/2 + 0.05) + rand() * ((bot_R1.x - R_mid) - (X_max/2 + 0.05));
                end
                palla.vx = 0; palla.vy = 0; palla.theta = 0; palla.last_touch = 'none';
            end
            
            planner_L1.reset(); planner_L2.reset(); planner_R1.reset(); planner_R2.reset();
            coach_L.assign_initial_roles(planner_L1, planner_L2); coach_R.assign_initial_roles(planner_R1, planner_R2);
        end
    end
    
    % --- FINE PARTITA: STAMPA RISULTATO ---
    fprintf('Partita %d | Team 1 vs Team 2: %d - %d | Autogol T1: %d | Autogol T2: %d\n', ...
            partita, score_L, score_R, autogol_L, autogol_R);
    
    % Aggiornamento Classifica Globale
    gol_fatti_tot_L = gol_fatti_tot_L + score_L;
    gol_fatti_tot_R = gol_fatti_tot_R + score_R;
    gol_subiti_tot_L = gol_subiti_tot_L + score_R;
    gol_subiti_tot_R = gol_subiti_tot_R + score_L;
    autogol_tot_L = autogol_tot_L + autogol_L;
    autogol_tot_R = autogol_tot_R + autogol_R;
    
    if score_L > score_R
        punti_L = punti_L + 3;
        vittorie_L = vittorie_L + 1;
    elseif score_R > score_L
        punti_R = punti_R + 3;
        vittorie_R = vittorie_R + 1;
    else
        punti_L = punti_L + 1;
        punti_R = punti_R + 1;
        pareggi = pareggi + 1;
    end
end

% ==========================================
% --- STAMPA CLASSIFICA FINALE ---
% ==========================================
diff_reti_L = gol_fatti_tot_L - gol_subiti_tot_L;
diff_reti_R = gol_fatti_tot_R - gol_subiti_tot_R;

disp(' ');
disp('================================================================');
disp('                      CLASSIFICA FINALE                         ');
disp('================================================================');
fprintf('%-16s | %-3s | %-2s | %-2s | %-2s | %-3s | %-3s | %-3s | %-3s\n', 'Squadra', 'Pti', 'V', 'N', 'P', 'GF', 'GS', 'DR', 'AG');
disp('----------------------------------------------------------------');
fprintf('%-16s | %-3d | %-2d | %-2d | %-2d | %-3d | %-3d | %-3d | %-3d\n', 'Team 1', punti_L, vittorie_L, pareggi, (num_partite - vittorie_L - pareggi), gol_fatti_tot_L, gol_subiti_tot_L, diff_reti_L, autogol_tot_L);
fprintf('%-16s | %-3d | %-2d | %-2d | %-2d | %-3d | %-3d | %-3d | %-3d\n', 'Team 2', punti_R, vittorie_R, pareggi, (num_partite - vittorie_R - pareggi), gol_fatti_tot_R, gol_subiti_tot_R, diff_reti_R, autogol_tot_R);
disp('================================================================');