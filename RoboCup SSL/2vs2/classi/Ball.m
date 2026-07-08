classdef Ball < handle
    
    properties
        % Modello
        x; y; theta;
        % Velocità
        vx; vy;
        % Parametri fisici
        r_p; m_p;
        % --- Tracking Autogol ---
        last_touch; % Memorizza l'ultima squadra che ha toccato la palla ('L' o 'R')
    end
    
    methods
        
        %--Costruttore
        function obj = Ball(x0, y0, r_p, m_p)
            obj.x = x0; 
            obj.y = y0; 
            obj.theta = 0;
            obj.vx = 0; 
            obj.vy = 0;
            obj.r_p = r_p; 
            obj.m_p = m_p;
            obj.last_touch = 'none'; % Inizializzazione neutra
        end
        
        %--Modello
        function update_dynamics(obj, Ts)
            % Coefficiente attrito volvente
            k_a = 0.98;
            obj.vx = obj.vx * k_a;
            obj.vy = obj.vy * k_a;
            
            % Soglia palla ferma
            k_stop = 0.05;
            if norm([obj.vx, obj.vy]) < k_stop
                obj.vx = 0; 
                obj.vy = 0;
            end
            
            % Aggiornamento modello (Eulero)
            obj.x = obj.x + obj.vx * Ts;
            obj.y = obj.y + obj.vy * Ts;
            
            % Palla ferma, valuto la "direzione"
            if norm([obj.vx, obj.vy]) > k_stop
                obj.theta = atan2(obj.vy, obj.vx);
            end
        end
        
        %--GRAFICA (Verrà ignorata nel torneo headless, ma la lasciamo per compatibilità)
        function draw(obj, Delta, show_action_radius)
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
                line_x = obj.x - (2 * Delta);
                plot([line_x, line_x], [-10, 10], 'm-.', 'LineWidth', 1.5);
            end
        end
    end
end