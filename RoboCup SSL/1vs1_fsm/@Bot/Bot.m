classdef Bot < handle
    
    properties
        % Stato del modello
        x; y; theta;
        % Geometria
        b; d; R_hex;
        % Input modello
        v; omega;
        % Parametri Fisici per urto
        m_r; I_r; e; 
        % Guadagni del PID
        Kp; Ki;
        % Guadagni controllo ottimo
        K_opt;
        %controllore selezionato
        ctrl_mode

        % Memoria dell'Integrale (Errori accumulati)
        err_sum_x;
        err_sum_y;
        
        % Proprietà per il movimento random
        target_x = [];
        target_y = [];
    end
    
    methods
        
        %--Costruttore oggetto
        function obj = Bot(x0, y0, theta0, b, d, R_hex, m_r, I_r, e, ctrl_mode, gains)
            obj.x = x0; obj.y = y0; obj.theta = theta0;
            obj.b = b; obj.d = d; obj.R_hex = R_hex;
            obj.m_r = m_r; obj.I_r = I_r; obj.e = e; 
            
            % --- SETUP DEL CERVELLO ---
            obj.ctrl_mode = upper(ctrl_mode); % Rende la stringa maiuscola per sicurezza
            
            switch obj.ctrl_mode
                case 'PID'
                    % Mi aspetto che gains sia un vettore [Kp, Ki]
                    obj.Kp = gains(1);
                    obj.Ki = gains(2);
                case {'H2', 'LQR_INT'}
                    % Mi aspetto che gains sia la matrice 2x4
                    obj.K_opt = gains;
                otherwise
                    error('Modalità di controllo "%s" non supportata!', obj.ctrl_mode);
            end
            
            % Inizializzazione memoria a zero
            obj.err_sum_x = 0;
            obj.err_sum_y = 0;
        end

        % --- DICHIARAZIONI DEI METODI ESTERNI ---
        % Inserisci solo la firma: cosa entra e cosa esce
        [u1, u2] = compute_control(obj, target_x_val, target_y_val, Ts)
        
        [u1, u2] = compute_wander_control(obj, area_x, area_y, ostacoli)
        
        linearize_and_move(obj, u1, u2, Ts)
        
        [center, radius] = get_active_circle(obj)
        
        [center, radius] = get_passive_circle(obj)
        
        [center, radius] = get_safety_circle(obj)
        
        [face_col, edge_col] = get_shirt(obj, team_name)
        
        draw(obj, team_name)
    end

end