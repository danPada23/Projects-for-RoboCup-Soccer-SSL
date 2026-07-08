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