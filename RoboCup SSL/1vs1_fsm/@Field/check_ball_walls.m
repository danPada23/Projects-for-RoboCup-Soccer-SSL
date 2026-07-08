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