classdef Ball < handle
    
    properties
        % Modello
        x; y; theta;
        % Velocità
        vx; vy;
        % Parametri fisici
        r_p; m_p;
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
        end

        % --- DICHIARAZIONI DEI METODI ESTERNI ---
        update_dynamics(obj, Ts)
        
        draw(obj, Delta, show_action_radius)
    end
    
end