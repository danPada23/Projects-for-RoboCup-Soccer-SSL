classdef Planner < handle
    
    properties
        % Stato corrente, precedente e di attacco
        fsm_state = 0;
        prev_state = -1;
        attacco_state = 1;
        % Punti noti utili
        P_A = [];
        P_Beyond = [];
        target_x;
        target_y;
        % Angolo desidearato
        locked_theta = 0;
        % Variabile per fsm
        calcolo_effettuato = false;
        % Punti per custom
        target_x_custom = 0;
        target_y_custom = 0;
        % Constanti di gioco
        R_min;
        R_max;
        R_mid;
        % Altri
        Ts;
        Delta;
        beyond_dist = 0.08;
        tol_reach_PA = 0.02;
        % Direzione 1 (sx->dx) o -1 (dx->sx)
        direction = 1; 
        
        % ==========================================
        % --- NUOVE PROPRIETA' 2vs2 ---
        % ==========================================
        role = 'leader';          % 'leader' o 'follower'
        follower_state = 'none';  % 'neutral', 'defense', 'offense'
        reception_radius = 0.2;   % Raggio di attivazione dello smarcamento (aggiornato dal Coach)
        
        % Variabili per il Wandering (Smarcamento) del Follower
        follower_micro_x = [];
        follower_micro_y = [];
        last_macro_x = 0;
        last_macro_y = 0;
    end
    
    methods
        
        %--Costruttore
        function obj = Planner(Ts, R_min, R_max, R_mid, Delta, start_x, start_y, dir)
            obj.Ts = Ts;
            obj.R_min = R_min;
            obj.R_max = R_max;
            obj.R_mid = R_mid;
            obj.Delta = Delta;
            obj.target_x = start_x;
            obj.target_y = start_y;
            
            if nargin >= 8
                obj.direction = dir;
            end
        end
        
        %--Logica Principale (Bivio 2vs2 + APF)
        function [u1_p, u2_p] = decide_action(obj, bot_player, bot_ally, planner_ally, team_enemies, palla, campo, X_max, Y_max, d)
            
            % 1. IL BIVIO COGNITIVO
            if strcmp(obj.role, 'leader')
                % FIX: Passiamo l'intero array team_enemies, non solo il primo!
                [u1_p, u2_p] = obj.execute_fsm(bot_player, team_enemies, palla, campo, X_max, Y_max, d);
            else
                [u1_p, u2_p] = obj.execute_follower(bot_player, bot_ally, planner_ally, palla, campo, X_max, Y_max);
            end
            
            % 2. FILTRO DI NAVIGAZIONE (APF)
            if (strcmp(obj.role, 'leader') && obj.fsm_state == 6) || ...
               (strcmp(obj.role, 'follower') && planner_ally.fsm_state == 6)
                % Nello Stop siamo immobili, niente deviazioni
            else
                [u1_p, u2_p] = obj.apply_apf(bot_player, team_enemies, bot_ally, u1_p, u2_p);
            end
        end
        
        %--Comportamento Follower a 5 Stati (8 Zone + Ultra)
        function [u1, u2] = execute_follower(obj, bot_player, bot_ally, planner_ally, palla, campo, X_max, Y_max)
            
            % 1. SINCRONIZZAZIONE STOP 
            if planner_ally.fsm_state == 6
                u1 = 0; u2 = 0;
                bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                return; 
            end
            
            % 2. LOGICA 8 ZONE (Y OPPOSTA)
            if bot_ally.y > (Y_max / 2)
                macro_y = Y_max * 0.25; 
            else
                macro_y = Y_max * 0.75; 
            end
            
            % 3. LOGICA X (5 COMPORTAMENTI)
            % Calcoliamo la X in base alla direzione (duale automatico)
            if obj.direction == 1
                switch obj.follower_state
                    case 'ultra defense', macro_x = 0.10;
                    case 'defense',       macro_x = 0.20;
                    case 'neutral',       macro_x = 0.35; % Prima del centro
                    case 'offense',       macro_x = 0.60;
                    case 'ultra offense', macro_x = 0.70;
                    otherwise,            macro_x = bot_player.x;
                end
            else % Team Destra (Speculare)
                switch obj.follower_state
                    case 'ultra defense', macro_x = 0.70;
                    case 'defense',       macro_x = 0.60;
                    case 'neutral',       macro_x = 0.45; % Prima del centro (dal suo lato)
                    case 'offense',       macro_x = 0.20;
                    case 'ultra offense', macro_x = 0.10;
                    otherwise,            macro_x = bot_player.x;
                end
            end
            
            % Clamping di sicurezza
            macro_x = max(campo.safe_x(1), min(campo.safe_x(2), macro_x));
            macro_y = max(campo.safe_y(1), min(campo.safe_y(2), macro_y));
            
            % 4. GESTIONE TARGET E MICRO-WANDERING RIDOTTO (2cm)
            dist_to_macro = norm([bot_player.x - macro_x, bot_player.y - macro_y]);
            
            if dist_to_macro > obj.reception_radius
                obj.follower_micro_x = macro_x;
                obj.follower_micro_y = macro_y;
            else
                % Se siamo in zona, attiviamo il fremito motorio stretto
                dist_macro_change = norm([macro_x - obj.last_macro_x, macro_y - obj.last_macro_y]);
                
                if isempty(obj.follower_micro_x) || dist_macro_change > 0.05 || ...
                   norm([bot_player.x - obj.follower_micro_x, bot_player.y - obj.follower_micro_y]) < 0.02
                    
                    ang = rand() * 2 * pi;
                    r = rand() * 0.02; % RIDOTTO A 2CM
                    obj.follower_micro_x = macro_x + r * cos(ang);
                    obj.follower_micro_y = macro_y + r * sin(ang);
                end
            end
            
            obj.last_macro_x = macro_x;
            obj.last_macro_y = macro_y;
            
            [u1, u2] = bot_player.compute_control(obj.follower_micro_x, obj.follower_micro_y, obj.Ts);
        end
        
        %--Filtro APF Reattivo (Protetto dalle Singolarità)
        function [u1_mod, u2_mod] = apply_apf(obj, bot_player, team_enemies, bot_ally, u1, u2)
            u1_mod = u1;
            u2_mod = u2;
            
            % 1. REPULSIONE NEMICI
            d_safe_enemy = 0.025; 
            K_rep_enemy = 0.15;   
            
            for i = 1:length(team_enemies)
                obs = team_enemies(i);
                delta_x = bot_player.x - obs.x;
                delta_y = bot_player.y - obs.y;
                dist = norm([delta_x, delta_y]);
                
                if dist < d_safe_enemy
                    dist_eff = max(dist, 0.015); 
                    F_mag = K_rep_enemy * (1/dist_eff - 1/d_safe_enemy) * (1/dist_eff^2);
                    F_mag = min(F_mag, 5.0); 
                    
                    rad_x = delta_x / dist_eff;
                    rad_y = delta_y / dist_eff;
                    tan_x = -rad_y;
                    tan_y = rad_x;
                    
                    u1_mod = u1_mod + F_mag * (0.4 * rad_x + 0.6 * tan_x);
                    u2_mod = u2_mod + F_mag * (0.4 * rad_y + 0.6 * tan_y);
                end
            end
            
            % 2. REPULSIONE ALLEATO (Solo Follower si scansa) 
            if strcmp(obj.role, 'follower') && ~isempty(bot_ally)
                d_safe_ally = 0.15; 
                K_rep_ally = 0.40;  
                
                delta_x = bot_player.x - bot_ally.x;
                delta_y = bot_player.y - bot_ally.y;
                dist = norm([delta_x, delta_y]);
                
                if dist < d_safe_ally
                    dist_eff = max(dist, 0.03); 
                    F_mag = K_rep_ally * (1/dist_eff - 1/d_safe_ally) * (1/dist_eff^2);
                    F_mag = min(F_mag, 8.0); 
                    
                    rad_x = delta_x / dist_eff;
                    rad_y = delta_y / dist_eff;
                    tan_x = -rad_y;
                    tan_y = rad_x;
                    
                    u1_mod = u1_mod + F_mag * (0.6 * rad_x + 0.4 * tan_x);
                    u2_mod = u2_mod + F_mag * (0.6 * rad_y + 0.4 * tan_y);
                end
            end
        end
        
        %--Logica FSM 
        %--Logica FSM 
        function [u1_p, u2_p] = execute_fsm(obj, bot_player, team_enemies, palla, campo, X_max, Y_max, d)
            
            dist_x = (palla.x - bot_player.x) * obj.direction;
            vel_palla = norm([palla.vx, palla.vy]);
            [B_center, ~] = bot_player.get_active_circle();
            u1_p = 0; u2_p = 0;
            
            % --- FIX 1: Scannerizza tutti i nemici per trovare il VERO ostacolo ---
            dist_enemy_ball = inf;
            bot_enemy = team_enemies(1);
            for i = 1:length(team_enemies)
                d_e = norm([team_enemies(i).x - palla.x, team_enemies(i).y - palla.y]);
                if d_e < dist_enemy_ball
                    dist_enemy_ball = d_e;
                    bot_enemy = team_enemies(i);
                end
            end
            
            dist_robot_ball = norm([palla.x - bot_player.x, palla.y - bot_player.y]);
            
            % OVERRIDE STOP 
            stop_ball = 0.05;
            if vel_palla > stop_ball
                obj.fsm_state = 6; % STOP è 6
                obj.calcolo_effettuato = false;
            end
            
            % OVERRIDE SPAZZATA 
            if obj.direction == 1
                zona_pericolo = campo.safe_x(1) + (X_max / 4);
                is_in_danger_zone = palla.x < zona_pericolo;
            else
                zona_pericolo = campo.safe_x(2) - (X_max / 4);
                is_in_danger_zone = palla.x > zona_pericolo;
            end
            
            margin_spazzata = 0.05; 
            
            % --- FIX 2: Rompiamo il loop tra Spazzata(8) e Attacco(5) ---
            if is_in_danger_zone && dist_robot_ball < (dist_enemy_ball - margin_spazzata) && ...
               obj.fsm_state ~= 8 && obj.fsm_state ~= 7 && obj.fsm_state ~= 6 && obj.fsm_state ~= 5
                obj.fsm_state = 8; % SPAZZATA è 8
                bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
            end
            
            % OVERRIDE ESCAPE
            escape_buffer = 0.015; 
            if vel_palla <= stop_ball && dist_robot_ball < (obj.Delta + escape_buffer) && ...
               obj.fsm_state ~= 5 && obj.fsm_state ~= 6 && ...
               obj.fsm_state ~= 7 && obj.fsm_state ~= 8
                
                obj.fsm_state = 7; % ESCAPE è 7
                bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
            end
            
            % --- LA RIGA MANCANTE RIPRISTINATA ---
            if obj.direction == 1
                my_goal_x = campo.safe_x(1);
            else
                my_goal_x = campo.safe_x(2);
            end
            
            % FSM ordinaria
            switch obj.fsm_state
                case 0 % WAIT
                    bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    obj.P_A = []; obj.P_Beyond = [];
                    
                    if dist_x <= obj.R_min
                        obj.fsm_state = 2; % BACK
                    elseif dist_x > obj.R_max
                        obj.fsm_state = 1; % PURSUE
                    else
                        obj.fsm_state = 4; % ACTION
                    end
                    
                case 1 % PURSUE
                    obj.target_x = palla.x - (obj.R_mid * obj.direction);
                    obj.target_y = palla.y;
                    [u1_p, u2_p] = bot_player.compute_control(obj.target_x, obj.target_y, obj.Ts);
                    
                    if dist_x >= obj.R_min && dist_x <= obj.R_max && dist_x > 0
                        obj.fsm_state = 4; % ACTION
                    end
                    
                case 2 % BACK 
                    obj.target_x = my_goal_x;
                    obj.target_y = Y_max / 2;
                    
                    v_vec = [obj.target_x - bot_player.x, obj.target_y - bot_player.y];
                    w_vec = [palla.x - bot_player.x, palla.y - bot_player.y];
                    
                    v_norm_sq = v_vec(1)^2 + v_vec(2)^2;
                    v_mag = sqrt(v_norm_sq);
                    p = dot(v_vec, w_vec);
                    
                    if v_mag > 0
                        d_dist = abs(v_vec(1)*w_vec(2) - v_vec(2)*w_vec(1)) / v_mag;
                        p_proj = p / v_mag; 
                    else
                        d_dist = inf; p_proj = 0;
                    end
                    
                    offset_safe = 0.04;
                    D_soglia = bot_player.R_hex + palla.r_p + offset_safe;
                    min_dist_frontale = bot_player.R_hex + palla.r_p + 0.02;
                    
                    if p_proj > min_dist_frontale && p < v_norm_sq && d_dist < D_soglia
                        u_hat = v_vec / v_mag;
                        n_hat = [-u_hat(2), u_hat(1)];
                        
                        D_evasion = D_soglia + 0.02; 
                        VP1 = [palla.x + D_evasion * n_hat(1), palla.y + D_evasion * n_hat(2)];
                        VP2 = [palla.x - D_evasion * n_hat(1), palla.y - D_evasion * n_hat(2)];
                        
                        VP1(1) = max(campo.safe_x(1), min(campo.safe_x(2), VP1(1)));
                        VP1(2) = max(campo.safe_y(1), min(campo.safe_y(2), VP1(2)));
                        VP2(1) = max(campo.safe_x(1), min(campo.safe_x(2), VP2(1)));
                        VP2(2) = max(campo.safe_y(1), min(campo.safe_y(2), VP2(2)));
                        
                        d_enemy_VP1 = norm([VP1(1) - bot_enemy.x, VP1(2) - bot_enemy.y]);
                        d_enemy_VP2 = norm([VP2(1) - bot_enemy.x, VP2(2) - bot_enemy.y]);
                        
                        if d_enemy_VP1 > d_enemy_VP2
                            obj.target_x_custom = VP1(1);
                            obj.target_y_custom = VP1(2);
                        else
                            obj.target_x_custom = VP2(1);
                            obj.target_y_custom = VP2(2);
                        end
                        
                        obj.fsm_state = 3; 
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    else
                        [u1_p, u2_p] = bot_player.compute_control(obj.target_x, obj.target_y, obj.Ts);
                        
                        if abs(bot_player.x - my_goal_x) <= 0.05
                            obj.fsm_state = 0; 
                            bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                        elseif dist_x >= obj.R_min && dist_x > 0
                            obj.fsm_state = 4; 
                        end
                    end
                    
                case 3 % CUSTOM 
                    [u1_p, u2_p] = bot_player.compute_control(obj.target_x_custom, obj.target_y_custom, obj.Ts);
                    
                    dist_to_vp = norm([obj.target_x_custom - bot_player.x, obj.target_y_custom - bot_player.y]);
                    
                    v_vec_check = [my_goal_x - bot_player.x, (Y_max / 2) - bot_player.y];
                    w_vec_check = [palla.x - bot_player.x, palla.y - bot_player.y];
                    v_mag_check = norm(v_vec_check);
                    
                    if v_mag_check > 0
                        d_dist_check = abs(v_vec_check(1)*w_vec_check(2) - v_vec_check(2)*w_vec_check(1)) / v_mag_check;
                        p_proj_check = dot(v_vec_check, w_vec_check) / v_mag_check;
                    else
                        d_dist_check = inf; p_proj_check = 0;
                    end
                    
                    % --- FIX: Ridefiniamo i margini per questo scope specifico ---
                    offset_safe = 0.04;
                    D_soglia = bot_player.R_hex + palla.r_p + offset_safe;
                    min_dist_frontale = bot_player.R_hex + palla.r_p + 0.02;
                    % -----------------------------------------------------------
                    
                    is_corridor_free = (d_dist_check > D_soglia) || (p_proj_check < min_dist_frontale);
                    
                    if is_corridor_free || (dist_to_vp < 0.05)
                        obj.fsm_state = 2; 
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    elseif dist_x > obj.R_min
                        obj.fsm_state = 4; 
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    end
                    
                case 4 % ACTION
                    u1_p = 0; u2_p = 0;
                    bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    
                    if ~obj.calcolo_effettuato
                        best_cost = inf;
                        best_aim_theta = 0;
                        best_fallback_dist = -inf;
                        fallback_theta = 0;
                        
                        if obj.direction == 1
                            angoli_test = deg2rad(-90:5:90);
                            target_x_porta = X_max;
                        else
                            angoli_test = deg2rad(90:5:270);
                            target_x_porta = 0;
                        end
                        
                        d_half = d / 2;
                        Y_sp_sup = Y_max - d_half;
                        Y_sp_inf = d_half;
                        Y_centro = Y_max / 2;
                        
                        W_dist = 1.0;
                        W_center = 0.5;
                        margine_palo = 0.02;
                        
                        R_obs = bot_enemy.R_hex + palla.r_p + 0.03; 
                        
                        for i = 1:length(angoli_test)
                            th_aim = angoli_test(i);
                            th_effettivo = th_aim;
                            
                            test_PA_x = palla.x - obj.Delta * cos(th_effettivo);
                            test_PA_y = palla.y - obj.Delta * sin(th_effettivo);
                            
                            is_PA_safe = (test_PA_x >= campo.safe_x(1)) && (test_PA_x <= campo.safe_x(2)) && ...
                                         (test_PA_y >= campo.safe_y(1)) && (test_PA_y <= campo.safe_y(2));
                            
                            y_end = palla.y + tan(th_effettivo) * (target_x_porta - palla.x);
                            
                            if y_end > Y_sp_sup
                                x_imp = palla.x + (Y_sp_sup - palla.y) / tan(th_effettivo);
                                th_refl = atan(-0.8 * tan(th_effettivo)); 
                                y_final = Y_sp_sup + tan(th_refl) * (target_x_porta - x_imp);
                                dist_path = norm([x_imp - palla.x, Y_sp_sup - palla.y]) + ...
                                    norm([target_x_porta - x_imp, y_final - Y_sp_sup]);
                                
                                d1 = obj.dist_pt_seg([bot_enemy.x, bot_enemy.y], [palla.x, palla.y], [x_imp, Y_sp_sup]);
                                d2 = obj.dist_pt_seg([bot_enemy.x, bot_enemy.y], [x_imp, Y_sp_sup], [target_x_porta, y_final]);
                                min_d_enemy = min(d1, d2);
                                
                            elseif y_end < Y_sp_inf
                                x_imp = palla.x + (Y_sp_inf - palla.y) / tan(th_effettivo);
                                th_refl = atan(-0.8 * tan(th_effettivo)); 
                                y_final = Y_sp_inf + tan(th_refl) * (target_x_porta - x_imp);
                                dist_path = norm([x_imp - palla.x, Y_sp_inf - palla.y]) + ...
                                    norm([target_x_porta - x_imp, y_final - Y_sp_inf]);
                                
                                d1 = obj.dist_pt_seg([bot_enemy.x, bot_enemy.y], [palla.x, palla.y], [x_imp, Y_sp_inf]);
                                d2 = obj.dist_pt_seg([bot_enemy.x, bot_enemy.y], [x_imp, Y_sp_inf], [target_x_porta, y_final]);
                                min_d_enemy = min(d1, d2);
                                
                            else
                                y_final = y_end;
                                dist_path = norm([target_x_porta - palla.x, y_final - palla.y]);
                                min_d_enemy = obj.dist_pt_seg([bot_enemy.x, bot_enemy.y], [palla.x, palla.y], [target_x_porta, y_final]);
                            end
                            
                            if is_PA_safe && (min_d_enemy > best_fallback_dist)
                                best_fallback_dist = min_d_enemy;
                                fallback_theta = th_aim;
                            end
                            
                            if ~is_PA_safe
                                cost = inf;
                            elseif y_final < (campo.y_goal_min + margine_palo) || y_final > (campo.y_goal_max - margine_palo)
                                cost = inf;
                            elseif min_d_enemy < R_obs
                                cost = inf;
                            else
                                cost_center = abs(y_final - Y_centro);
                                cost = (W_dist * dist_path) + (W_center * cost_center);
                            end
                            
                            if cost < best_cost
                                best_cost = cost;
                                best_aim_theta = th_aim;
                            end
                        end
                        
                        if isinf(best_cost)
                            best_aim_theta = fallback_theta;
                        end
                        
                        obj.locked_theta = best_aim_theta;
                        obj.P_A = [palla.x - obj.Delta * cos(obj.locked_theta);
                                   palla.y - obj.Delta * sin(obj.locked_theta)];
                        obj.P_Beyond = [palla.x + obj.beyond_dist * cos(obj.locked_theta);
                                        palla.y + obj.beyond_dist * sin(obj.locked_theta)];
                        
                        obj.calcolo_effettuato = true;
                        obj.fsm_state = 5; 
                        obj.attacco_state = 1;
                    end
                    
                case 5 % ATTACCO
                    if obj.attacco_state == 1
                        obj.target_x = obj.P_A(1);
                        obj.target_y = obj.P_A(2);
                        
                        dist_PA = norm([B_center(1) - obj.P_A(1), B_center(2) - obj.P_A(2)]);
                        if dist_PA < obj.tol_reach_PA
                            obj.attacco_state = 2;
                        end
                    elseif obj.attacco_state == 2
                        obj.target_x = obj.P_Beyond(1);
                        obj.target_y = obj.P_Beyond(2);
                    end
                    
                    [u1_p, u2_p] = bot_player.compute_control(obj.target_x, obj.target_y, obj.Ts);
                    
                    dist_to_beyond = norm([bot_player.x - obj.P_Beyond(1), bot_player.y - obj.P_Beyond(2)]);
                    
                    if dist_x < 0 
                        obj.fsm_state = 6; 
                    elseif dist_robot_ball > (obj.R_max + 0.15)
                        % FIX 3: Sgancia l'attacco se la palla si allontana troppo
                        obj.fsm_state = 0; 
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                        obj.calcolo_effettuato = false;
                    elseif obj.attacco_state == 2 && dist_to_beyond < 0.05
                        % FIX 3: Uscita d'emergenza a fine corsa
                        obj.fsm_state = 0; 
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                        obj.calcolo_effettuato = false;
                    end
                    
                case 6 % STOP
                    bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    
                    if vel_palla < 0.005
                        obj.fsm_state = 0; 
                        obj.calcolo_effettuato = false;
                    end
                    
                case 7 % ESCAPE
                    v_escape = [bot_player.x - palla.x, bot_player.y - palla.y];
                    norm_escape = norm(v_escape);
                    if norm_escape == 0
                        v_escape = [1, 0];
                        norm_escape = 1;
                    end
                    
                    u_hat_escape = v_escape / norm_escape;
                    
                    obj.target_x = bot_player.x + u_hat_escape(1) * 0.2;
                    obj.target_y = bot_player.y + u_hat_escape(2) * 0.2;
                    
                    obj.target_x = max(campo.safe_x(1), min(campo.safe_x(2), obj.target_x));
                    obj.target_y = max(campo.safe_y(1), min(campo.safe_y(2), obj.target_y));
                    
                    [u1_p, u2_p] = bot_player.compute_control(obj.target_x, obj.target_y, obj.Ts);
                    
                    if dist_robot_ball > (obj.Delta + 0.02)
                        obj.fsm_state = 0; 
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    end
                    
                case 8 % SPAZZATA
                    u1_p = 0; u2_p = 0;
                    bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    
                    if obj.direction == 1
                        target_x_porta = X_max;
                    else
                        target_x_porta = 0;
                    end
                    
                    th_aim = atan2(Y_max / 2 - palla.y, target_x_porta - palla.x);
                    
                    obj.locked_theta = th_aim;
                    obj.P_A = [palla.x - obj.Delta * cos(obj.locked_theta);
                               palla.y - obj.Delta * sin(obj.locked_theta)];
                    obj.P_Beyond = [palla.x + obj.beyond_dist * cos(obj.locked_theta);
                                    palla.y + obj.beyond_dist * sin(obj.locked_theta)];
                    
                    obj.calcolo_effettuato = true;
                    obj.fsm_state = 5; 
                    obj.attacco_state = 1;
            end
            
            obj.prev_state = obj.fsm_state;
        end
        
        function d = dist_pt_seg(obj, P, V, W)
            l2 = sum((V - W).^2);
            if l2 == 0
                d = norm(P - V);
                return;
            end
            t = max(0, min(1, dot(P - V, W - V) / l2));
            projection = V + t * (W - V);
            d = norm(P - projection);
        end

        function reset(obj)
            obj.fsm_state = 0;
            obj.prev_state = -1;
            obj.calcolo_effettuato = false;
            obj.P_A = [];
            obj.P_Beyond = [];
            obj.attacco_state = 1; % FIX 4: Fondamentale per i cambi di leadership!
        end
    end
end