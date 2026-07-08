function check_bot_walls(obj, bot)
            if bot.x <= obj.safe_x(1)
                bot.x = obj.safe_x(1);
                % Saturazione della posizione x del robot sul limite sinistro sicuro
            elseif bot.x >= obj.safe_x(2)
                bot.x = obj.safe_x(2);
                % Saturazione della posizione x del robot sul limite destro sicuro
            end
            
            if bot.y <= obj.safe_y(1)
                bot.y = obj.safe_y(1);
                % Saturazione della posizione y del robot sul limite inferiore sicuro   
            elseif bot.y >= obj.safe_y(2)
                bot.y = obj.safe_y(2);
                % Saturazione della posizione y del robot sul limite superiore sicuro
            end
end