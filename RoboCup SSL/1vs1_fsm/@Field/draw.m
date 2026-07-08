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