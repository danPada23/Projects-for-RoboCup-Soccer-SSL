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

        % --- DICHIARAZIONI DEI METODI ESTERNI ---
        [u1_p, u2_p] = decide_action(obj, bot_player, bot_enemy, palla, campo, X_max, Y_max, d)
        
        d = dist_pt_seg(obj, P, V, W)
        
        reset(obj)

    end
end