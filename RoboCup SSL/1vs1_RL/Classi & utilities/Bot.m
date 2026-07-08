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
        
        %--Controllo Multimodale
        function [u1, u2] = compute_control(obj, target_x_val, target_y_val, Ts)
           
            % 1. Estraggo le coordinate di B (Comune)
            [center, ~] = obj.get_active_circle();
            
            % 2. Calcolo errore attuale (Comune)
            ex = target_x_val - center(1);
            ey = target_y_val - center(2);
            
            % 3. Accumulo integrale e Anti-Windup (Comune)
            obj.err_sum_x = obj.err_sum_x + ex * Ts;
            obj.err_sum_y = obj.err_sum_y + ey * Ts;
            
            limit_int = 0.5; 
            obj.err_sum_x = max(-limit_int, min(limit_int, obj.err_sum_x));
            obj.err_sum_y = max(-limit_int, min(limit_int, obj.err_sum_y));
            
            % 4. STRATEGIA DI CONTROLLO
            switch obj.ctrl_mode
                case 'PID'
                    % Legge PID classica (Disaccoppiata)
                    u1 = obj.Kp * ex + obj.Ki * obj.err_sum_x;
                    u2 = obj.Kp * ey + obj.Ki * obj.err_sum_y;
                    
                case {'H2', 'LQR_INT'}
                    % Legge Ottima MIMO con Effetto Integrale
                    % X_err = [xe_x; xe_y; ep_x; ep_y]
                    X_err = [obj.err_sum_x; obj.err_sum_y; -ex; -ey];
                    U = obj.K_opt * X_err;
                    u1 = U(1); 
                    u2 = U(2);
                    
                case 'LQR_STD'
                    % Esempio di come potresti aggiungere un LQR base
                    % che ignora l'integrale (usa solo l'errore proporzionale)
                    X_err_prop = [-ex; -ey];
                    U = obj.K_opt * X_err_prop;
                    u1 = U(1); 
                    u2 = U(2);
            end
        end
        
        %--Random walk function
        function [u1, u2] = compute_wander_control(obj, area_x, area_y, ostacoli)

            % area_x e aree_y sono i range desiderati per l'area di spwan 
            % del bot
            
            % Estraggo le coordinate di B
            [center, ~] = obj.get_active_circle();
            
            % Definisco il margine minimo di spawn (meta campo destra)
            margine = obj.b + obj.d + 0.01; 
            
            % Se l'obiettivo è vuoto o è troppo vicino lo riassegno 
            if isempty(obj.target_x) || norm([obj.target_x - center(1), obj.target_y - center(2)]) < 0.1
                
                % Calcolo della "scatola" sicura in cui estrarre il target
                min_x = area_x(1) + margine;
                max_x = area_x(2) - margine;
                min_y = area_y(1) + margine;
                max_y = area_y(2) - margine;
                
                % Generazione coordinate casuali nella scatola sicura
                obj.target_x = min_x + rand() * (max_x - min_x);
                obj.target_y = min_y + rand() * (max_y - min_y);
            end
            
            % Due contributi: attrattivo (standard) + repulsivo (APF method) 
            
            % Attrattivo (verso il punto target, PID solo proporzionale)
            u1_attr = obj.Kp * (obj.target_x - center(1));
            u2_attr = obj.Kp * (obj.target_y - center(2));
            
            % Repulsivo (se vicino ad altri bot entro un certo raggio)
            u1_rep = 0; u2_rep = 0;
            distanza_sicurezza = obj.R_hex * 4; 
            
            % Calcolo distanza bot e altri_bot, se < calcolo forza
            % repulsiva, inversamente proporzionale alla distanza
            for i = 1:length(ostacoli)
                altro_bot = ostacoli(i);
                dist = norm([obj.x - altro_bot.x, obj.y - altro_bot.y]);
                
                if dist < distanza_sicurezza && dist > 0.01 
                    dir_x = (obj.x - altro_bot.x) / dist; 
                    dir_y = (obj.y - altro_bot.y) / dist;
                    forza = 0.5 * (1/dist - 1/distanza_sicurezza); 
                    u1_rep = u1_rep + forza * dir_x;
                    u2_rep = u2_rep + forza * dir_y;
                end
            end
            
            % Contributo totale controllo (attr. + rep.)
            u1 = u1_attr + u1_rep;
            u2 = u2_attr + u2_rep;
        end
        
        %--Modello
        function linearize_and_move(obj, u1, u2, Ts)
            
            %Limite fisico robot
            v_sat = 0.3; % 30 cm/s
            
            % I/O linearization
            v_des = u1 * cos(obj.theta) + u2 * sin(obj.theta);
            omega_des = (1/obj.b) * (-u1 * sin(obj.theta) + u2 * cos(obj.theta));
            
            % Saturazione velocità
            if abs(v_des) > v_sat
                v_des = sign(v_des) * v_sat;
            end
            
            obj.v = v_des;
            obj.omega = omega_des;
            
            % Aggiornamento modello (Eulero)
            obj.x = obj.x + Ts * obj.v * cos(obj.theta);
            obj.y = obj.y + Ts * obj.v * sin(obj.theta);
            obj.theta = obj.theta + Ts * obj.omega;
        end
        
        %--Geometria (cerchio attacco)
        function [center, radius] = get_active_circle(obj)
            center = [obj.x + obj.b * cos(obj.theta); 
                      obj.y + obj.b * sin(obj.theta)];
            radius = obj.b;
        end
        
        %--Geometria (cerchio difesa)
        function [center, radius] = get_passive_circle(obj)
            center = [obj.x; obj.y];
            radius = obj.R_hex;
        end
        
        %--Geometria (cerchio di sicurezza)
        function [center, radius] = get_safety_circle(obj)
            center = [obj.x; obj.y];
            radius = obj.b + obj.d;
        end
        
        %--GUARDAROBA SQUADRE
        function [face_col, edge_col] = get_shirt(~, team_name)
            
            % Restituisce il colore primario (Face) e secondario (Edge)
            switch lower(team_name)
                case 'inter'
                    face_col = [0, 0.2, 0.8]; % Blu acceso
                    edge_col = [0, 0, 0];     % Nero
                case 'milan'
                    face_col = [0.8, 0, 0];   % Rosso
                    edge_col = [0, 0, 0];     % Nero
                case 'juve'
                    face_col = [1, 1, 1];     % Bianco
                    edge_col = [0, 0, 0];     % Nero
                case 'lazio'
                    face_col = [0.4, 0.7, 1]; % Celeste
                    edge_col = [1, 1, 1];     % Bianco
                case 'roma'
                    face_col = [0.6, 0.1, 0.1]; % Rosso scuro (Pompeiano)
                    edge_col = [1, 0.7, 0];     % Giallo ocra
                case 'fiorentina'
                    face_col = [0.4, 0, 0.6]; % Viola
                    edge_col = [1, 1, 1];     % Bianco
                case 'napoli'
                    face_col = [0, 0.5, 1];   % Azzurro
                    edge_col = [1, 1, 1];     % Bianco
                otherwise
                    % Colore di default (es. Ciano e Verde acqua) se la squadra non esiste
                    face_col = [0, 1, 1];       
                    edge_col = [0, 0.5, 0.5];
            end
        end

        %--GRAFICA
        function draw(obj, team_name)

            % Se non viene passata la squadra, mettiamo un default
            if nargin < 2
                team_name = 'default'; 
            end
            
            % Richiama il guardaroba per ottenere i colori
            [face_col, edge_col] = obj.get_shirt(team_name);
            
            % Disegno esagono regolare dividendo il cerchio in 6 parti (+ offset per avere la testa a destra)
            alpha_angles = (0:6) * (pi/3) + (pi/6);
            Pos_loc = [obj.R_hex*cos(alpha_angles); obj.R_hex*sin(alpha_angles)];

            % Ruoto l'esagono nel sistema di coordinate attuali
            DCM = [cos(obj.theta), -sin(obj.theta); sin(obj.theta), cos(obj.theta)];
            
            exa = DCM * Pos_loc + [obj.x; obj.y];
            
            % Disegno l'esagono usando la maglia della squadra
            fill(exa(1,:), exa(2,:), face_col, 'EdgeColor', edge_col, 'LineWidth', 2.5);
            
            % Centro esagono
            plot(obj.x, obj.y, 'k.', 'MarkerSize', 10);
            
            % Raggio b
            [B, ~] = obj.get_active_circle();
            plot([obj.x B(1)], [obj.y B(2)], 'r-', 'LineWidth', 1.5);

            % Punto B
            [B, ~] = obj.get_active_circle();
            plot(B(1), B(2), 'ro', 'MarkerSize', 4, 'MarkerEdgeColor','r','MarkerFaceColor','r');
            
            
            % Mostro gli assi del bot
            quiver(obj.x, obj.y, 0.01*cos(obj.theta), 0.01*sin(obj.theta), 0, 'Color', 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
            quiver(obj.x, obj.y, -(obj.R_hex+0.01)*sin(obj.theta), (obj.R_hex+0.01)*cos(obj.theta), 0, 'Color', 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5);
        end
    end
end