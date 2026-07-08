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