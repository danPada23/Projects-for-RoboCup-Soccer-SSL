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
        
        %--Logica fsm ed azioni da svolgere
        function [u1_p, u2_p] = decide_action(obj, bot_player, bot_enemy, palla, campo, X_max, Y_max, d)
            
            dist_x = (palla.x - bot_player.x) * obj.direction;
            [B_center, ~] = bot_player.get_active_circle();
            u1_p = 0; u2_p = 0;
            
            % OVERRIDE STOP: Se la palla è in movimento, FORZA lo STOP.
            if palla.is_moving()
                obj.fsm_state = 7;
                obj.calcolo_effettuato = false;
            end

            % OVERRIDE Fuga: Valutato SOLO se la palla è ferma.
            dist_robot_ball = norm([palla.x - bot_player.x, palla.y - bot_player.y]);
            dist_enemy_ball = norm([palla.x - bot_enemy.x, palla.y - bot_enemy.y]); 
            escape_buffer = 0.015; 
            
            if ~palla.is_moving() && dist_robot_ball < (obj.Delta + escape_buffer) && ...
               obj.fsm_state ~= 6 && obj.fsm_state ~= 7 && ...
               obj.fsm_state ~= 8 && obj.fsm_state ~= 3 && obj.fsm_state ~= 9
                
                obj.fsm_state = 8;
                bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
            end
            
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
                        obj.fsm_state = 2;
                    elseif dist_x > obj.R_max
                        obj.fsm_state = 1;
                    else
                        obj.fsm_state = 5;
                    end
                    
                case 1 % PURSUE
                    obj.target_x = palla.x - (obj.R_mid * obj.direction);
                    obj.target_y = palla.y;
                    [u1_p, u2_p] = bot_player.compute_control(obj.target_x, obj.target_y, obj.Ts);
                    
                    if dist_x >= obj.R_min && dist_x <= obj.R_max && dist_x > 0
                        obj.fsm_state = 5;
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
                        d_dist = inf;
                        p_proj = 0;
                    end
                    
                    D_soglia = bot_player.R_hex + palla.r_p + 0.08;
                    min_dist_frontale = bot_player.R_hex + palla.r_p + 0.02;
                    
                    if p_proj > min_dist_frontale && p < v_norm_sq && d_dist < D_soglia
                        u_hat = v_vec / v_mag;
                        n_hat = [-u_hat(2), u_hat(1)];

                        offset_safe = 0.08;
                        D_safe = D_soglia + offset_safe;
                        VP1 = [palla.x + D_safe * n_hat(1), palla.y + D_safe * n_hat(2)];
                        VP2 = [palla.x - D_safe * n_hat(1), palla.y - D_safe * n_hat(2)];
                        
                        % CLAMPING: Limitiamo i Via Point dentro i margini sicuri
                        VP1(1) = max(campo.safe_x(1), min(campo.safe_x(2), VP1(1)));
                        VP1(2) = max(campo.safe_y(1), min(campo.safe_y(2), VP1(2)));
                        
                        VP2(1) = max(campo.safe_x(1), min(campo.safe_x(2), VP2(1)));
                        VP2(2) = max(campo.safe_y(1), min(campo.safe_y(2), VP2(2)));
                        
                        if abs(VP1(2) - Y_max/2) < abs(VP2(2) - Y_max/2)
                            obj.target_x_custom = VP1(1);
                            obj.target_y_custom = VP1(2);
                        else
                            obj.target_x_custom = VP2(1);
                            obj.target_y_custom = VP2(2);
                        end
                        
                        obj.fsm_state = 4;
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    else
                        [u1_p, u2_p] = bot_player.compute_control(obj.target_x, obj.target_y, obj.Ts);
                        
                        if abs(bot_player.x - my_goal_x) <= 0.05
                            obj.fsm_state = 3;
                            bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                        elseif dist_x >= obj.R_min && dist_x > 0
                            obj.fsm_state = 5;
                        end
                    end
                    
                case 3 % DIFESA
                    th_des = atan2(palla.y - bot_player.y, palla.x - bot_player.x);
                    obj.target_x = my_goal_x + bot_player.b * cos(th_des);
                    obj.target_y = Y_max / 2  + bot_player.b * sin(th_des);
                    [u1_p, u2_p] = bot_player.compute_control(obj.target_x, obj.target_y, obj.Ts);
                    
                    % Il Portiere Volante
                    margin_spazzata = 0.05; % Vantaggio di 5 cm richiesto per uscire
                    if dist_robot_ball < (dist_enemy_ball - margin_spazzata) && dist_robot_ball > obj.Delta
                        obj.fsm_state = 9; % Vai in SPAZZATA
                    elseif dist_x > (obj.R_min + 0.1)
                        obj.fsm_state = 5;
                    end
                    
                case 4 % CUSTOM
                    % --- AGGIUNTA: Gestione Destro/Sinistro per l'IA ---
                    % Ricalcoliamo il target mantenendo un approccio "largo" (es. 15 cm dietro la palla).
                    % Il moltiplicatore obj.direction (1 o -1) assicura che il bot destro vada verso 
                    % la sua porta e non verso il centro del campo.
                    obj.target_x_custom = palla.x - (0.15 * obj.direction); 
                    obj.target_y_custom = palla.y;
                    % ---------------------------------------------------

                    % --- IL TUO CODICE ORIGINALE ---
                    [u1_p, u2_p] = bot_player.compute_control(obj.target_x_custom, obj.target_y_custom, obj.Ts);
                    dist_to_vp = norm([obj.target_x_custom - bot_player.x, obj.target_y_custom - bot_player.y]);
                    
                    if dist_to_vp < 0.05
                        obj.fsm_state = 2;
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    elseif dist_x > obj.R_min
                        obj.fsm_state = 5;
                        bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    end
                    
                case 5 % ACTION
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
                        obj.fsm_state = 6;
                        obj.attacco_state = 1;
                    end
                    
                case 6 % ATTACCO
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
                    
                    % Nota: Non serve più l'if su vel_palla > 0.05 qui, 
                    % perché se la colpisci, ci pensa l'Override Supremo al ciclo successivo!
                    if dist_x < 0 % Se ho superato la palla mancandola, fermati
                        obj.fsm_state = 7;
                    end
                    
                case 7 % STOP (Congelamento)
                    % Il robot frena (u1=0, u2=0 preimpostati a inizio funzione)
                    bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    
                    % Esce dallo stop solo quando la palla è ferma
                    if ~palla.is_moving()
                        obj.fsm_state = 0; % Risveglio sincronizzato
                        obj.calcolo_effettuato = false;
                    end
                    
                case 8 % ESCAPE
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
                    
                case 9 % SPAZZATA
                    u1_p = 0; u2_p = 0;
                    bot_player.err_sum_x = 0; bot_player.err_sum_y = 0;
                    
                    if obj.direction == 1
                        target_x_porta = X_max;
                    else
                        target_x_porta = 0;
                    end
                    
                    % Tiro dritto verso il centro avversario
                    th_aim = atan2(Y_max / 2 - palla.y, target_x_porta - palla.x);
                    
                    obj.locked_theta = th_aim;
                    obj.P_A = [palla.x - obj.Delta * cos(obj.locked_theta);
                               palla.y - obj.Delta * sin(obj.locked_theta)];
                    obj.P_Beyond = [palla.x + obj.beyond_dist * cos(obj.locked_theta);
                                    palla.y + obj.beyond_dist * sin(obj.locked_theta)];
                    
                    obj.calcolo_effettuato = true;
                    obj.fsm_state = 6;
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
        end
    end
end