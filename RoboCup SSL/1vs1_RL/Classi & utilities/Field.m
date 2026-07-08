classdef Field < handle
    properties
        lim_x; lim_y;       % Limiti fisici del campo lungo gli assi x e y [m]
        safe_x; safe_y;     % Limiti fisici del campo lungo gli assi x e y [m]
        
        % Nuovi limiti di sicurezza per la palla
        ball_safe_x; ball_safe_y;  % Limiti fisici del campo lungo gli assi x e y [m]
        
        % Dimensioni geometriche della porta
        goal_width;         % larghezza lungo y [m]
        goal_depth;         % profondità lungo x [m]
        y_goal_min;
        y_goal_max;         % Estremi verticali dell'apertura della porta [m]
        
        grid_X; grid_Y;     % Coordinate precomputate della griglia grafica del campo
    end
    
    methods
        function obj = Field(lim_x, lim_y, safe_x, safe_y, goal_w, goal_d)
            obj.lim_x = lim_x; obj.lim_y = lim_y;     % Assegnazione dei limiti fisici del campo
            obj.safe_x = safe_x; obj.safe_y = safe_y; % Assegnazione della regione sicura riservata ai robot
            
            % Calcolo del limite palla (distanza d/2 dal bordo fisico)
            % safe_x(1) corrisponde esattamente a 'd'
            d_half = safe_x(1) / 2;  % Mezzo margine geometrico usato per definire la regione sicura della palla
            
            % Definizione della regione sicura della palla, più vicina ai bordi rispetto a quella dei robot
            obj.ball_safe_x = [lim_x(1) + d_half, lim_x(2) - d_half];
            obj.ball_safe_y = [lim_y(1) + d_half, lim_y(2) - d_half];
            
            if nargin < 5
                obj.goal_width = 0.2; 
                % Valore di default della larghezza porta
            else
                obj.goal_width = goal_w;
                % Assegnazione della larghezza porta fornita in ingresso
            end
            
            if nargin < 6
                obj.goal_depth = 0.05; 
                % Valore di default della profondità porta
            else
                obj.goal_depth = goal_d;
                % Assegnazione della profondità porta fornita in ingresso
            end
            
            y_mid = (lim_y(1) + lim_y(2)) / 2; % Coordinata y del centro del campo

            % Calcolo degli estremi verticali dell'apertura della porta
            obj.y_goal_min = y_mid - (obj.goal_width / 2);
            obj.y_goal_max = y_mid + (obj.goal_width / 2);
            
            step_grid = 0.05; % Passo della griglia grafica del campo [m]
            % Punti della griglia lungo gli assi x e y
            grid_pts_x = step_grid:step_grid:(lim_x(2) - step_grid);
            grid_pts_y = step_grid:step_grid:(lim_y(2) - step_grid);
            
            % Segmenti verticali della griglia separati da NaN per il disegno continuo
            x_v = [grid_pts_x; grid_pts_x; NaN(size(grid_pts_x))];
            y_v = [zeros(size(grid_pts_x)); repmat(lim_y(2), size(grid_pts_x)); NaN(size(grid_pts_x))];
            
            % Segmenti orizzontali della griglia separati da NaN per il disegno continuo
            x_h = [zeros(size(grid_pts_y)); repmat(lim_x(2), size(grid_pts_y)); NaN(size(grid_pts_y))];
            y_h = [grid_pts_y; grid_pts_y; NaN(size(grid_pts_y))];
            
            obj.grid_X = [x_v(:); x_h(:)];
            obj.grid_Y = [y_v(:); y_h(:)];
            % Memorizzazione delle coordinate complete della griglia grafica
        end
        
        function draw(obj)
            % 1. Sfondo nero esterno
            bg_x = obj.lim_x(1) - obj.goal_depth;
            bg_y = obj.lim_y(1);
            bg_w = (obj.lim_x(2) - obj.lim_x(1)) + 2 * obj.goal_depth;
            bg_h = obj.lim_y(2) - obj.lim_y(1);
            % Dimensioni del rettangolo esterno che include anche le porte

            rectangle('Position', [bg_x, bg_y, bg_w, bg_h], 'FaceColor', 'k', 'EdgeColor', 'k'); % Disegno dello sfondo esterno nero
                      
            % 2. Sfondo verde solido
            rectangle('Position', [obj.lim_x(1), obj.lim_y(1), obj.lim_x(2)-obj.lim_x(1), obj.lim_y(2)-obj.lim_y(1)], ...
                      'LineWidth', 2, 'EdgeColor', [0 0.5 0], 'FaceColor', [0.7 1 0.7]); % Disegno dell'area di gioco principale
                  
            % 3. Griglia
            plot(obj.grid_X, obj.grid_Y, '--', 'Color', [0 0 0], 'LineWidth', 0.01);  % Disegno della griglia interna del campo
            
            % 4. Porte
            rectangle('Position', [obj.lim_x(1) - obj.goal_depth, obj.y_goal_min, obj.goal_depth, obj.goal_width], ...
                      'LineWidth', 2, 'EdgeColor', [0 0.4470 0.7410], 'FaceColor', [0.3010 0.7450 0.9330], 'FaceAlpha', 0.4);   % Disegno della porta sinistra
            rectangle('Position', [obj.lim_x(2), obj.y_goal_min, obj.goal_depth, obj.goal_width], ...
                      'LineWidth', 2, 'EdgeColor', [0 0.4470 0.7410], 'FaceColor', [0.3010 0.7450 0.9330], 'FaceAlpha', 0.4);   % Disegno della porta destra
            
            % 5. Linea di centrocampo
            x_mid = (obj.lim_x(1) + obj.lim_x(2)) / 2; % Coordinata x del centrocampo
            plot([x_mid, x_mid], [obj.safe_y(1), obj.safe_y(2)], 'w--', 'LineWidth', 2); % Disegno della linea di centrocampo nella regione sicura
            
            % 6. Limiti di sicurezza Robot (Bianco punteggiato)
            w_safe = obj.safe_x(2) - obj.safe_x(1);
            h_safe = obj.safe_y(2) - obj.safe_y(1);
            % Dimensioni della regione sicura dei robot

            rectangle('Position', [obj.safe_x(1), obj.safe_y(1), w_safe, h_safe], ...
                      'LineWidth', 5, 'EdgeColor', [1 1 1], 'LineStyle', ':');  % Disegno del perimetro operativo sicuro dei robot
                      
            % 7. Limiti di sicurezza Palla (Giallo tratteggiato)
            w_bsafe = obj.ball_safe_x(2) - obj.ball_safe_x(1);
            h_bsafe = obj.ball_safe_y(2) - obj.ball_safe_y(1);
            % Dimensioni della regione sicura della palla

            rectangle('Position', [obj.ball_safe_x(1), obj.ball_safe_y(1), w_bsafe, h_bsafe], ...
                      'LineWidth', 1.5, 'EdgeColor', 'y', 'LineStyle', '--'); % Disegno del perimetro operativo sicuro della palla
        end
        
        function apply_repulsion(obj, palla, Ts)
            % Calcola le forze repulsive se la palla si trova nei bordi o negli angoli "morti"
            
            % I margini di repulsione si estendono leggermente oltre la safe_zone del robot
            % per impedire alla palla di rimanere in una posizione in cui il P_A finirebbe fuori.
            margin_y = obj.safe_y(1) + 0.04; % 2 cm di cuscinetto dai bordi lunghi (margine di repulsione)
            margin_x = obj.safe_x(1) + 0.04; % 2 cm di cuscinetto da fondo campo (margine di repulsione)
            
            % Costanti elastiche (K) - Modifica per variare l'intensità della discesa
            K_edge = 6;    % Pendenza "leggera" (i bordi lunghi sputano la palla lentamente)
            K_corner = 20; % Pendenza "ripida" (gli angoli spingono forte verso il centro)
            
            v_rep_x = 0;
            v_rep_y = 0;
            % Inizializzazione delle componenti della velocità repulsiva
            
            % --- ASSE Y: Repulsione Bordi Lunghi ---
            if palla.y < margin_y
                depth_y = margin_y - palla.y;
                v_rep_y = K_edge * depth_y;
                % Repulsione verso l'alto se la palla è troppo vicina al bordo inferiore
            elseif palla.y > (obj.lim_y(2) - margin_y)
                depth_y = palla.y - (obj.lim_y(2) - margin_y);
                v_rep_y = -K_edge * depth_y;
                % Repulsione verso il basso se la palla è troppo vicina al bordo superiore
            end
            
            % --- ASSE X: Repulsione Angoli/Fondo (Esclusa la Porta) ---
            in_corner_x = false; % Flag che indica se la palla si trova vicino a un fondo campo
            if palla.x < margin_x
                depth_x = margin_x - palla.x;
                v_rep_x = K_corner * depth_x;
                in_corner_x = true;
                % Repulsione verso destra se la palla è troppo vicina al lato sinistro
            elseif palla.x > (obj.lim_x(2) - margin_x)
                depth_x = palla.x - (obj.lim_x(2) - margin_x);
                v_rep_x = -K_corner * depth_x;
                in_corner_x = true;
                % Repulsione verso sinistra se la palla è troppo vicina al lato destro
            end
            
            % --- SINERGIA ANGOLO ---
            % Se siamo in un angolo (sia X che Y attivi), potenziamo la spinta Y 
            % usando il moltiplicatore K_corner per fargli superare prima il margine
            if in_corner_x && v_rep_y ~= 0
                v_rep_y = sign(v_rep_y) * (K_corner * abs(margin_y - palla.y));
                % Se la palla è in un angolo, la repulsione verticale viene rinforzata
            end
            
            % --- ECCEZIONE: Zona Goal ---
            % Se la palla è nell'apertura della porta, disabilita la repulsione X
            % altrimenti il muro invisibile le impedirebbe di segnare.
            if palla.y >= obj.y_goal_min && palla.y <= obj.y_goal_max
                v_rep_x = 0; % La repulsione lungo x viene annullata in corrispondenza dell'apertura della porta
            end
            
            % Applico la variazione di velocità (Accelerazione * Tempo)
            palla.vx = palla.vx + (v_rep_x * Ts);
            palla.vy = palla.vy + (v_rep_y * Ts);
            % Aggiornamento delle velocità della palla tramite contributo repulsivo discreto
        end
        
        function goal_scored = check_ball_walls(obj, ball)
            goal_scored = 0; 
            % Variabile di uscita:
            % 0 = nessun gol
            % 1 = gol nella porta sinistra
            % 2 = gol nella porta destra
            r = ball.r_p; % Raggio della palla
            
            % --- 1. CHECK GOL ---
            if (ball.x + r <= obj.lim_x(1)) && (ball.x - r >= obj.lim_x(1) - obj.goal_depth) && ...
               (ball.y - r >= obj.y_goal_min) && (ball.y + r <= obj.y_goal_max)
                goal_scored = 1; return; 
                % La palla è completamente entrata nella porta sinistra
            end
            
            if (ball.x - r >= obj.lim_x(2)) && (ball.x + r <= obj.lim_x(2) + obj.goal_depth) && ...
               (ball.y - r >= obj.y_goal_min) && (ball.y + r <= obj.y_goal_max)
                goal_scored = 2; return;
                % La palla è completamente entrata nella porta destra
            end
            
            % --- 2. RIMBALZI ASSE Y (Usa i nuovi limiti di sicurezza palla) ---
            if (ball.y - r) <= obj.ball_safe_y(1)
                ball.y = obj.ball_safe_y(1) + r;    % Riposizionamento della palla sul bordo inferiore sicuro
                ball.vy = -0.8 * ball.vy;           % Inversione anelastica della velocità verticale
            elseif (ball.y + r) >= obj.ball_safe_y(2)
                ball.y = obj.ball_safe_y(2) - r;    % Riposizionamento della palla sul bordo superiore sicuro
                ball.vy = -0.8 * ball.vy;           % Inversione anelastica della velocità verticale
            end
            
            % --- 3. RIMBALZI ASSE X E PORTE LATO SINISTRO ---
            if (ball.x - r) <= obj.ball_safe_x(1)
                if ball.y - r >= obj.y_goal_min && ball.y + r <= obj.y_goal_max
                     % Se la palla è allineata con l'apertura della porta si applica la geometria reale della porta
                    if ball.x < obj.lim_x(1) 
                        if (ball.y - r) <= obj.y_goal_min
                            ball.y = obj.y_goal_min + r;
                            ball.vy = -0.8 * ball.vy;
                            % Rimbalzo sul palo inferiore della porta sinistra
                        elseif (ball.y + r) >= obj.y_goal_max
                            ball.y = obj.y_goal_max - r;
                            ball.vy = -0.8 * ball.vy;
                            % Rimbalzo sul palo superiore della porta sinistra
                        end
                        if (ball.x - r) <= obj.lim_x(1) - obj.goal_depth
                            ball.x = obj.lim_x(1) - obj.goal_depth + r;
                            ball.vx = -0.8 * ball.vx;
                            % Rimbalzo sul fondo della porta sinistra
                        end
                    end
                else
                    ball.x = obj.ball_safe_x(1) + r;
                    ball.vx = -0.8 * ball.vx; 
                    % Fuori dall'apertura della porta, la palla rimbalza sul limite sicuro sinistro
                end
            end
            
            % --- 4. RIMBALZI ASSE X E PORTE LATO DESTRO ---
            if (ball.x + r) >= obj.ball_safe_x(2)
                if ball.y - r >= obj.y_goal_min && ball.y + r <= obj.y_goal_max
                    % Se la palla è allineata con l'apertura della porta si applica la geometria reale della porta
                    if ball.x > obj.lim_x(2)
                        if (ball.y - r) <= obj.y_goal_min
                            ball.y = obj.y_goal_min + r;
                            ball.vy = -0.8 * ball.vy;
                            % Rimbalzo sul palo inferiore della porta destra
                        elseif (ball.y + r) >= obj.y_goal_max
                            ball.y = obj.y_goal_max - r;
                            ball.vy = -0.8 * ball.vy;
                            % Rimbalzo sul palo superiore della porta destra
                        end
                        if (ball.x + r) >= obj.lim_x(2) + obj.goal_depth
                            ball.x = obj.lim_x(2) + obj.goal_depth - r;
                            ball.vx = -0.8 * ball.vx;
                            % Rimbalzo sul fondo della porta destra
                        end
                    end
                else
                    ball.x = obj.ball_safe_x(2) - r;
                    ball.vx = -0.8 * ball.vx; 
                    % Fuori dall'apertura della porta, la palla rimbalza sul limite sicuro destro
                end
            end
        end
        
        function check_bot_walls(obj, bot)
            if bot.x <= obj.safe_x(1)
                bot.x = obj.safe_x(1);
                % Saturazione della posizione x del robot sul limite sinistro sicuro
            elseif bot.x >= obj.safe_x(2)
                bot.x = obj.safe_x(2);
                % Saturazione della posizione x del robot sul limite destro sicuro
            end
            
            if bot.y <= obj.safe_y(1)
                bot.y = obj.safe_y(1);
                % Saturazione della posizione y del robot sul limite inferiore sicuro   
            elseif bot.y >= obj.safe_y(2)
                bot.y = obj.safe_y(2);
                % Saturazione della posizione y del robot sul limite superiore sicuro
            end
        end
        
        % --- NUOVO: Aggiunto bot_id per l'analisi forense ---
        function resolve_collision(obj, bot, ball, fsm_state, bot_id)
            % Se lo stato non viene passato (retrocompatibilità), assumiamo -1
            if nargin < 4
                fsm_state = -1;
            end
            
            % Se il bot_id non viene passato (retrocompatibilità), assumiamo 0 (sconosciuto)
            if nargin < 5
                bot_id = 0;
            end
            
            [B_center, b_rad] = bot.get_active_circle();
            [C_center, c_rad] = bot.get_passive_circle();
            % Estrazione dei due cerchi del robot:
            % attivo = frontale/operativo
            % passivo = corpo centrale
            
            dist_B = norm(B_center - [ball.x; ball.y]);
            dist_C = norm(C_center - [ball.x; ball.y]);
            % Distanze tra palla e rispettivi centri dei cerchi del robot
            v_r_vec = [bot.v * cos(bot.theta); bot.v * sin(bot.theta)];
            % Velocità traslazionale del centro del robot nel riferimento globale
            
            % --- NERF PORTIERE ---
            % Il cerchio ATTIVO entra in gioco SOLO se il robot NON è in stato 3 (DIFESA) ne in STOP 
            if dist_B <= (b_rad + ball.r_p) && fsm_state ~= 3 && fsm_state ~= 7
                r_r = [bot.b * cos(bot.theta); bot.b * sin(bot.theta)]; % Vettore che collega il centro del robot al centro del cerchio attivo
                n_vec = [ball.x; ball.y] - B_center;
                n_hat = n_vec / norm(n_vec);                            % Versore normale di contatto tra cerchio attivo e palla
                
                v_B = [v_r_vec(1) - bot.omega * r_r(2);
                       v_r_vec(2) + bot.omega * r_r(1)];                % Velocità del punto attivo, ottenuta sommando contributo traslazionale e rotazionale
                
                v_rel_n = dot(v_B - [ball.vx; ball.vy], n_hat);         % Componente normale della velocità relativa tra punto attivo e palla
                if v_rel_n > 0
                    cross_rn = r_r(1)*n_hat(2) - r_r(2)*n_hat(1);       % Termine geometrico del momento della forza impulsiva rispetto al centro del robot
                    % Numeratore e denominatore della legge impulsiva d'urto
                    num = (1 + bot.e) * v_rel_n;
                    den = (1/bot.m_r) + (1/ball.m_p) + (cross_rn^2 / bot.I_r);
                    j = num / den;                                      % Intensità dell'impulso scambiato nell'urto
                    % Aggiornamento della velocità della palla dopo l'urto con il cerchio attivo
                    ball.vx = ball.vx + (j / ball.m_p) * n_hat(1);
                    ball.vy = ball.vy + (j / ball.m_p) * n_hat(2);
                    
                    % --- NUOVO: Registrazione del Tocco in Memoria ---
                    ball.ultimo_tocco_id = bot_id;
                    % Memorizziamo l'intensità calcolando la norma della velocità del punto attivo al momento dell'urto
                    ball.energia_ultimo_tocco = norm(v_B); 
                end
            elseif dist_C <= (c_rad + ball.r_p)
                % Se il cerchio attivo non interviene, si valuta l'urto con il cerchio passivo
                n_vec = [ball.x; ball.y] - C_center;
                n_hat = n_vec / norm(n_vec); % Versore normale di contatto tra cerchio passivo e palla
                v_rel_n = dot(v_r_vec - [ball.vx; ball.vy], n_hat);  % Componente normale della velocità relativa tra robot e palla
                
                if v_rel_n > 0
                    % Parametri della legge impulsiva semplificata per il corpo passivo
                    num = (1 + bot.e) * v_rel_n;
                    den = (1/bot.m_r) + (1/ball.m_p);
                    j = num / den; % Intensità dell'impulso trasmesso alla palla
                    % Aggiornamento della velocità della palla dopo l'urto con il corpo passivo
                    ball.vx = ball.vx + (j / ball.m_p) * n_hat(1);
                    ball.vy = ball.vy + (j / ball.m_p) * n_hat(2);
                    
                    % --- NUOVO: Registrazione del Tocco in Memoria ---
                    ball.ultimo_tocco_id = bot_id;
                    % Memorizziamo l'intensità calcolando la norma della velocità traslazionale del corpo
                    ball.energia_ultimo_tocco = norm(v_r_vec);
                end
            end
        end

        function resolve_bot_bot_collision(~, bot1, bot2)
            % Prevenzione compenetrazione tra due robot (Hard Repulsion)
            delta_x = bot2.x - bot1.x;
            delta_y = bot2.y - bot1.y;
            dist = norm([delta_x, delta_y]);
            
            % Distanza minima consentita (due corpi passivi R_hex che si toccano)
            min_dist = bot1.R_hex + bot2.R_hex; 
            
            if dist < min_dist && dist > 0
                % Calcolo versore di direzione da bot1 a bot2
                nx = delta_x / dist;
                ny = delta_y / dist;
                
                % Entità della compenetrazione
                overlap = min_dist - dist;
                
                % Correzione posizionale: si dividono equamente l'overlap 
                % venendo spinti in direzioni opposte lungo la normale
                bot1.x = bot1.x - (overlap / 2) * nx;
                bot1.y = bot1.y - (overlap / 2) * ny;
                
                bot2.x = bot2.x + (overlap / 2) * nx;
                bot2.y = bot2.y + (overlap / 2) * ny;
            end
        end
        
    end
end