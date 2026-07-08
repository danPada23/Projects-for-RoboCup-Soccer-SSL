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