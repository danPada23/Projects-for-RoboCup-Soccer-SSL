 %--Random walk function
        function [u1, u2] = compute_wander_control(obj, area_x, area_y, ostacoli)

            % area_x e aree_y sono i range desiderati per l'area di spwan 
            % del bot
            
            % Estraggo le coordinate di B
            [center, ~] = obj.get_active_circle();
            
            % Definisco il margine minimo di spawn (meta campo destra)
            margine = obj.b + obj.d + 0.01; 
            
            % Se l'obiettivo è vuoto o è troppo vicino lo riassegno 
            if isempty(obj.target_x) || norm([obj.target_x - center(1), obj.target_y - center(2)]) < 0.1
                
                % Calcolo della "scatola" sicura in cui estrarre il target
                min_x = area_x(1) + margine;
                max_x = area_x(2) - margine;
                min_y = area_y(1) + margine;
                max_y = area_y(2) - margine;
                
                % Generazione coordinate casuali nella scatola sicura
                obj.target_x = min_x + rand() * (max_x - min_x);
                obj.target_y = min_y + rand() * (max_y - min_y);
            end
            
            % Due contributi: attrattivo (standard) + repulsivo (APF method) 
            
            % Attrattivo (verso il punto target, PID solo proporzionale)
            u1_attr = obj.Kp * (obj.target_x - center(1));
            u2_attr = obj.Kp * (obj.target_y - center(2));
            
            % Repulsivo (se vicino ad altri bot entro un certo raggio)
            u1_rep = 0; u2_rep = 0;
            distanza_sicurezza = obj.R_hex * 4; 
            
            % Calcolo distanza bot e altri_bot, se < calcolo forza
            % repulsiva, inversamente proporzionale alla distanza
            for i = 1:length(ostacoli)
                altro_bot = ostacoli(i);
                dist = norm([obj.x - altro_bot.x, obj.y - altro_bot.y]);
                
                if dist < distanza_sicurezza && dist > 0.01 
                    dir_x = (obj.x - altro_bot.x) / dist; 
                    dir_y = (obj.y - altro_bot.y) / dist;
                    forza = 0.5 * (1/dist - 1/distanza_sicurezza); 
                    u1_rep = u1_rep + forza * dir_x;
                    u2_rep = u2_rep + forza * dir_y;
                end
            end
            
            % Contributo totale controllo (attr. + rep.)
            u1 = u1_attr + u1_rep;
            u2 = u2_attr + u2_rep;
        end