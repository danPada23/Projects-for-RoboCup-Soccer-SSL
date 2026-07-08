%--Modello
        function linearize_and_move(obj, u1, u2, Ts)
            
            %Limite fisico robot
            v_sat = 0.3; % 30 cm/s
            
            % I/O linearization
            v_des = u1 * cos(obj.theta) + u2 * sin(obj.theta);
            omega_des = (1/obj.b) * (-u1 * sin(obj.theta) + u2 * cos(obj.theta));
            
            % Saturazione velocità
            if abs(v_des) > v_sat
                v_des = sign(v_des) * v_sat;
            end
            
            obj.v = v_des;
            obj.omega = omega_des;
            
            % Aggiornamento modello (Eulero)
            obj.x = obj.x + Ts * obj.v * cos(obj.theta);
            obj.y = obj.y + Ts * obj.v * sin(obj.theta);
            obj.theta = obj.theta + Ts * obj.omega;
        end