%--GRAFICA
        function draw(obj, Delta, show_action_radius)
            
            % Se non specificato non mostrare il raggio di azione
            if nargin < 3
                show_action_radius = false;
            end
            
            % Disegno Palla
            th = linspace(0, 2*pi, 50);
            fill(obj.x + obj.r_p*cos(th), obj.y + obj.r_p*sin(th), [1 1 0], 'EdgeColor', 'k');
            
            % Cerchio di approccio (Raggio = Delta)
            plot(obj.x + Delta*cos(th), obj.y + Delta*sin(th), 'b--', 'LineWidth', 1.5);
            
            % Frecce orientamento
            q_x = obj.r_p + 0.01;
            quiver(obj.x, obj.y, q_x*cos(obj.theta), q_x*sin(obj.theta), 0, 'Color', 'r', 'LineWidth', 2, 'MaxHeadSize', 0.8);
            quiver(obj.x, obj.y, -q_x*sin(obj.theta), q_x*cos(obj.theta), 0, 'Color', 'b', 'LineWidth', 2, 'MaxHeadSize', 0.8);
            
            % RAGGIO DI AZIONE DINAMICO
            if show_action_radius
                
                % Calcolo la posizione esatta 2*Delta sulla sinistra della PALLA (obj.x)
                line_x = obj.x - (2 * Delta);
                
                plot([line_x, line_x], [-10, 10], 'm-.', 'LineWidth', 1.5);
            end
        end