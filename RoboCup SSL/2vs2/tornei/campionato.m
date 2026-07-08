clear; 
clc; 
close all;
clear classes;

% ==========================================
% --- SETUP CAMPIONATO MASTER ---
% ==========================================
num_ripetizioni = 10;
rec_rad = 0.15; % Raggio fisso
stanch_fissa = 0.0; % Stanchezza nulla

nomi_tattiche = {'ULTRA DIFENSIVO', 'DIFENSIVO', 'EQUILIBRATO', 'OFFENSIVO', 'ULTRA OFFENSIVO'};
num_team = length(nomi_tattiche);

% Array per la classifica globale (Indice 1 a 5 corrisponde alle tattiche)
pti_tot = zeros(1, num_team);
vittorie_tot = zeros(1, num_team);
pareggi_tot = zeros(1, num_team);
sconfitte_tot = zeros(1, num_team);
gf_tot = zeros(1, num_team);
gs_tot = zeros(1, num_team);
ag_tot = zeros(1, num_team); % Autogol globali

disp('================================================================');
disp('          AVVIO CAMPIONATO MASTER: SCONTRO TRA TATTICHE         ');
disp('================================================================');
fprintf('Formato: Girone Andata/Ritorno ripetuto %d volte.\n', num_ripetizioni);
fprintf('Partite totali previste: %d\n', num_ripetizioni * (num_team * (num_team - 1)));
disp('================================================================');

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
durata_tempo = 60; 

match_count = 0;

% ==========================================
% --- TRIPLO LOOP: TORNEO -> SQUADRA L -> SQUADRA R ---
% ==========================================
for iter = 1:num_ripetizioni
    fprintf('\n\n>>> ============================================================== <<<\n');
    fprintf('>>>                   INIZIO GIRONE %d DI %d                       <<<\n', iter, num_ripetizioni);
    fprintf('>>> ============================================================== <<<\n\n');
    
    % Contatori azzerati per la classifica di questo singolo girone
    pti_iter = zeros(1, num_team);
    vittorie_iter = zeros(1, num_team);
    pareggi_iter = zeros(1, num_team);
    sconfitte_iter = zeros(1, num_team);
    gf_iter = zeros(1, num_team);
    gs_iter = zeros(1, num_team);
    ag_iter = zeros(1, num_team);
    
    for t1 = 1:num_team
        for t2 = 1:num_team
            
            % Evitiamo che una squadra giochi contro se stessa
            if t1 == t2
                continue;
            end
            
            match_count = match_count + 1;
            
            % Setup Partita
            campo = Field(lim_x, lim_y, safe_x, safe_y, goal_width, goal_depth);
            bot_L_start_x = campo.safe_x(1); bot_R_start_x = campo.safe_x(2);
            start_y_up = Y_max * 0.75; start_y_dw = Y_max * 0.25;
            
            ball_start_y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));
            if rand() > 0.5
                ball_start_x = (bot_L_start_x + R_mid) + rand() * ((X_max/2 - 0.05) - (bot_L_start_x + R_mid));
            else
                ball_start_x = (X_max/2 + 0.05) + rand() * ((bot_R_start_x - R_mid) - (X_max/2 + 0.05));
            end
            
            palla = Ball(ball_start_x, ball_start_y, r_p, m_p);
            palla.last_touch = 'none'; % Inizializzazione per tracking autogol
            
            bot_L1 = Bot(bot_L_start_x, start_y_up, 0, b, d, A, m_r, I_r, e, Kp, Ki); 
            bot_L2 = Bot(bot_L_start_x, start_y_dw, 0, b, d, A, m_r, I_r, e, Kp, Ki); 
            bot_R1 = Bot(bot_R_start_x, start_y_up, pi, b, d, A, m_r, I_r, e, Kp, Ki); 
            bot_R2 = Bot(bot_R_start_x, start_y_dw, pi, b, d, A, m_r, I_r, e, Kp, Ki); 
            
            planner_L1 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_L1.x, bot_L1.y, 1);
            planner_L2 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_L2.x, bot_L2.y, 1);
            planner_R1 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_R1.x, bot_R1.y, -1);
            planner_R2 = Planner(Ts, R_min, R_max, R_mid, Delta, bot_R2.x, bot_R2.y, -1);
            
            % T1 = Squadra in Casa (L), T2 = Squadra in Trasferta (R)
            coach_L = Coach('Team 1', rec_rad, 'offense');
            coach_R = Coach('Team 2', rec_rad, 'defense');
            
            coach_L.tattica = t1; coach_L.stanchezza = stanch_fissa;
            coach_R.tattica = t2; coach_R.stanchezza = stanch_fissa;
            
            planner_L1.reception_radius = rec_rad; planner_L2.reception_radius = rec_rad;
            planner_R1.reception_radius = rec_rad; planner_R2.reception_radius = rec_rad;
            
            coach_L.assign_initial_roles(planner_L1, planner_L2);
            coach_R.assign_initial_roles(planner_R1, planner_R2);
            
            score_L = 0; score_R = 0;
            autogol_L = 0; autogol_R = 0;
            tempo_simulato = 0; tempo_corrente = 1;
            
            % --- FISICA DELLA SINGOLA PARTITA ---
            while tempo_corrente <= 2
                tempo_simulato = tempo_simulato + Ts;
                
                enemies_L = [bot_R1, bot_R2]; enemies_R = [bot_L1, bot_L2];
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
                for i = 1:4, campo.check_bot_walls(all_bots(i)); end
                
                get_eff_state = @(plan) (strcmp(plan.role, 'follower') && strcmp(plan.follower_state, 'defense')) * 3 + ...
                                        (strcmp(plan.role, 'leader') || (strcmp(plan.role, 'follower') && ~strcmp(plan.follower_state, 'defense'))) * plan.fsm_state;
                
                campo.resolve_collision(bot_L1, palla, get_eff_state(planner_L1), 'L');
                campo.resolve_collision(bot_L2, palla, get_eff_state(planner_L2), 'L');
                campo.resolve_collision(bot_R1, palla, get_eff_state(planner_R1), 'R');
                campo.resolve_collision(bot_R2, palla, get_eff_state(planner_R2), 'R');
                
                goal_status = campo.check_ball_walls(palla);
                
                if goal_status > 0
                    if goal_status == 1
                        score_R = score_R + 1;
                        if strcmp(palla.last_touch, 'L'), autogol_L = autogol_L + 1; end
                    elseif goal_status == 2
                        score_L = score_L + 1;
                        if strcmp(palla.last_touch, 'R'), autogol_R = autogol_R + 1; end
                    end
                    
                    bot_L1.x = campo.safe_x(1); bot_L1.y = start_y_up; bot_L1.theta = 0;
                    bot_L2.x = campo.safe_x(1); bot_L2.y = start_y_dw; bot_L2.theta = 0;
                    bot_R1.x = campo.safe_x(2); bot_R1.y = start_y_up; bot_R1.theta = pi;
                    bot_R2.x = campo.safe_x(2); bot_R2.y = start_y_dw; bot_R2.theta = pi;
                    for i=1:4, all_bots(i).v = 0; all_bots(i).omega = 0; all_bots(i).err_sum_x = 0; all_bots(i).err_sum_y = 0; end
                    
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
                
                if tempo_simulato >= durata_tempo
                    tempo_corrente = tempo_corrente + 1; tempo_simulato = 0;
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
            end % Fine While Partita
            
            % --- AGGIORNAMENTO STATISTICHE ---
            fprintf('Match %3d | %-16s vs %-16s: %d - %d (Autogol: %d - %d)\n', match_count, nomi_tattiche{t1}, nomi_tattiche{t2}, score_L, score_R, autogol_L, autogol_R);
            
            % Statistiche Girone Singolo
            gf_iter(t1) = gf_iter(t1) + score_L; gs_iter(t1) = gs_iter(t1) + score_R; ag_iter(t1) = ag_iter(t1) + autogol_L;
            gf_iter(t2) = gf_iter(t2) + score_R; gs_iter(t2) = gs_iter(t2) + score_L; ag_iter(t2) = ag_iter(t2) + autogol_R;
            
            % Statistiche Globali
            gf_tot(t1) = gf_tot(t1) + score_L; gs_tot(t1) = gs_tot(t1) + score_R; ag_tot(t1) = ag_tot(t1) + autogol_L;
            gf_tot(t2) = gf_tot(t2) + score_R; gs_tot(t2) = gs_tot(t2) + score_L; ag_tot(t2) = ag_tot(t2) + autogol_R;
            
            if score_L > score_R
                pti_iter(t1) = pti_iter(t1) + 3; vittorie_iter(t1) = vittorie_iter(t1) + 1; sconfitte_iter(t2) = sconfitte_iter(t2) + 1;
                pti_tot(t1) = pti_tot(t1) + 3; vittorie_tot(t1) = vittorie_tot(t1) + 1; sconfitte_tot(t2) = sconfitte_tot(t2) + 1;
            elseif score_R > score_L
                pti_iter(t2) = pti_iter(t2) + 3; vittorie_iter(t2) = vittorie_iter(t2) + 1; sconfitte_iter(t1) = sconfitte_iter(t1) + 1;
                pti_tot(t2) = pti_tot(t2) + 3; vittorie_tot(t2) = vittorie_tot(t2) + 1; sconfitte_tot(t1) = sconfitte_tot(t1) + 1;
            else
                pti_iter(t1) = pti_iter(t1) + 1; pti_iter(t2) = pti_iter(t2) + 1;
                pareggi_iter(t1) = pareggi_iter(t1) + 1; pareggi_iter(t2) = pareggi_iter(t2) + 1;
                
                pti_tot(t1) = pti_tot(t1) + 1; pti_tot(t2) = pti_tot(t2) + 1;
                pareggi_tot(t1) = pareggi_tot(t1) + 1; pareggi_tot(t2) = pareggi_tot(t2) + 1;
            end
            
        end % Fine t2
    end % Fine t1
    
    % --- STAMPA CLASSIFICA SINGOLO GIRONE ---
    dr_iter = gf_iter - gs_iter;
    T_Iter = table(nomi_tattiche', pti_iter', vittorie_iter', pareggi_iter', sconfitte_iter', gf_iter', gs_iter', dr_iter', ag_iter', ...
        'VariableNames', {'Tattica', 'Punti', 'V', 'N', 'P', 'GF', 'GS', 'DR', 'AG'});
    T_Iter = sortrows(T_Iter, {'Punti', 'DR'}, {'descend', 'descend'});

    disp(' ');
    disp('-------------------------------------------------------------------------');
    fprintf('                    CLASSIFICA GIRONE %d                                \n', iter);
    disp('-------------------------------------------------------------------------');
    fprintf('%-18s | %-4s | %-3s | %-3s | %-3s | %-4s | %-4s | %-4s | %-4s\n', 'TATTICA', 'PTI', 'V', 'N', 'P', 'GF', 'GS', 'DR', 'AG');
    disp('-------------------------------------------------------------------------');
    for i = 1:num_team
        fprintf('%-18s | %-4d | %-3d | %-3d | %-3d | %-4d | %-4d | %-4d | %-4d\n', ...
            T_Iter.Tattica{i}, T_Iter.Punti(i), T_Iter.V(i), T_Iter.N(i), ...
            T_Iter.P(i), T_Iter.GF(i), T_Iter.GS(i), T_Iter.DR(i), T_Iter.AG(i));
    end
    disp('-------------------------------------------------------------------------');
    
end % Fine Iterazioni

% ==========================================
% --- CLASSIFICA FINALE E ORDINAMENTO ---
% ==========================================
dr_tot = gf_tot - gs_tot;

T_Classifica = table(nomi_tattiche', pti_tot', vittorie_tot', pareggi_tot', sconfitte_tot', gf_tot', gs_tot', dr_tot', ag_tot', ...
    'VariableNames', {'Tattica', 'Punti', 'V', 'N', 'P', 'GF', 'GS', 'DR', 'AG'});
T_Classifica = sortrows(T_Classifica, {'Punti', 'DR'}, {'descend', 'descend'});

disp(' ');
disp('=========================================================================');
disp('             CLASSIFICA FINALE - MASTER DELLE TATTICHE (200 MATCH)       ');
disp('=========================================================================');
fprintf('%-18s | %-4s | %-3s | %-3s | %-3s | %-4s | %-4s | %-4s | %-4s\n', 'TATTICA', 'PTI', 'V', 'N', 'P', 'GF', 'GS', 'DR', 'AG');
disp('-------------------------------------------------------------------------');
for i = 1:num_team
    fprintf('%-18s | %-4d | %-3d | %-3d | %-3d | %-4d | %-4d | %-4d | %-4d\n', ...
        T_Classifica.Tattica{i}, T_Classifica.Punti(i), T_Classifica.V(i), T_Classifica.N(i), ...
        T_Classifica.P(i), T_Classifica.GF(i), T_Classifica.GS(i), T_Classifica.DR(i), T_Classifica.AG(i));
end
disp('=========================================================================');