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


        % --- DICHIARAZIONI DEI METODI ESTERNI ---
        draw(obj)
        
        apply_repulsion(obj, palla, Ts)
        
        goal_scored = check_ball_walls(obj, ball)
        
        check_bot_walls(obj, bot)
        
        resolve_collision(obj, bot, ball, fsm_state, bot_id)
        
        resolve_bot_bot_collision(obj, bot1, bot2)
        
    end

end