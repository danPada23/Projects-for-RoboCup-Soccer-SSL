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